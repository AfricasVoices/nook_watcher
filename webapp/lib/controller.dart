library controller;

import 'dart:async';

import 'logger.dart';
import 'model.dart' as model;
import 'platform.dart' as platform;
import 'view.dart' as view;

Logger log = new Logger('controller.dart');

final NEEDS_REPLY_METRICS_COLLECTION_KEY = 'needs_reply_metrics';
final SYSTEM_EVENTS_COLLECTION_KEY = 'system_events';
final SYSTEM_METRICS_ROOT_COLLECTION_KEY = 'systems';
final SYSTEM_METRICS_MACHINE_NAME = 'miranda';
final DIR_SIZE_METRICS_ROOT_COLLECTION_KEY = 'dir_size_metrics';

final PROJECTS = ['Lark_KK-Project-2020-COVID19', 'Lark_KK-Project-2020-COVID19-KE-URBAN',
  'Lark_KK-Project-2020-COVID19-SOM-CC', 'Lark_KK-Project-2020-COVID19-SOM-IMAQAL', 'Lark_KK-Project-2020-COVID19-SOM-UNICEF'];

final DRIVERS = ['coda_adapter', 'pubsub_handler', 'firebase_adapter'];

enum UIAction {
  userSignedIn,
  userSignedOut,
  signInButtonClicked,
  signOutButtonClicked,
  needsReplyDataUpdated,
  driversDataUpdated,
  systemMetricsDataUpdated,
  dirSizeMetricsDataUpdated,
  systemEventsDataUpdated,
  projectSelected,
  chartsFiltered,
  tabSwitched,
  driverMetricsSelected
}

enum ChartPeriodFilters {
  hours1,
  hours4,
  hours10,
  days1,
  days8,
  days15,
  month1,
  alltime,
}

List<ChartPeriodFilters> hourFilters = [
  ChartPeriodFilters.hours1,
  ChartPeriodFilters.hours4,
  ChartPeriodFilters.hours10,
  ChartPeriodFilters.days1
];

List<ChartPeriodFilters> dayFilters = [
  ChartPeriodFilters.days1,
  ChartPeriodFilters.days8,
  ChartPeriodFilters.days15,
  ChartPeriodFilters.month1,
  ChartPeriodFilters.alltime
];


enum ChartType {
  conversation,
  driver,
  system,
}

class Data {}

class ChartFilterData extends Data {
  ChartPeriodFilters periodFilter;
  ChartFilterData(this.periodFilter);
}

class ChartTypeData extends Data {
  ChartType chartType;
  ChartTypeData(this.chartType);
}

class ProjectData extends Data {
  String project;
  ProjectData(this.project);
}

class UserData extends Data {
  String displayName;
  String email;
  String photoUrl;
  UserData(this.displayName, this.email, this.photoUrl);
}

List<model.NeedsReplyData> needsReplyDataList;
Map<String, List<model.DriverData>> driversDataMap;
Map<String, List<model.SystemEventsData>> systemEventsDataMap;
List<model.SystemMetricsData> systemMetricsDataList;
List<model.DirectorySizeMetricsData> dirSizeMetricsDataList;

ChartType selectedTab;
String selectedProject;
ChartPeriodFilters selectedPeriodFilter;
Map<String, Map<String, bool>> driverMetricsFilters;

model.User signedInUser;

Map<String, Timer> projectTimers = {};

StreamSubscription needsReplyMetricsSubscription;
List<StreamSubscription> driverMetricsSubscriptions = [];

void init() async {
  view.init();
  await platform.init();
}

void initUI() {
  needsReplyDataList = [];
  driversDataMap = {};
  systemEventsDataMap = {};
  systemMetricsDataList = [];
  dirSizeMetricsDataList = [];
  driverMetricsFilters = {};

  selectedTab = view.contentView.getChartTypeUrlFilter() ?? ChartType.conversation;
  view.contentView.toogleTabView(selectedTab);

  selectedPeriodFilter = view.contentView.getChartPeriodUrlFilter() ?? ChartPeriodFilters.days1;
  var periodFilterOptions = selectedTab == ChartType.driver ? hourFilters : dayFilters;
  view.ChartFiltersView().periodFilterOptions = periodFilterOptions;
  if (!periodFilterOptions.contains(selectedPeriodFilter)) {
    selectedPeriodFilter = selectedTab == ChartType.driver ? ChartPeriodFilters.hours1 : ChartPeriodFilters.days1;
  }
  view.ChartFiltersView().selectedPeriodFilter = selectedPeriodFilter;

  selectedProject = view.contentView.getProjectUrlFilter() ?? PROJECTS.first;
  view.contentView.projectSelectorView.projectOptions = PROJECTS;
  view.contentView.projectSelectorView.selectedProject = selectedProject;

  view.contentView.setUrlFilters(selectedTab, selectedProject, selectedPeriodFilter);

  listenForNeedsReplyMetrics(selectedProject);
  listenForDriverMetrics(selectedProject, DRIVERS);
  listenForSystemEvents(PROJECTS);
  listenForSystemMetrics();
  // listenForDirectoryMetrics(); // not yet in use
}

void listenForNeedsReplyMetrics(String project) {
  // clear up the old data while the new data loads
  needsReplyDataList.clear();
  command(UIAction.needsReplyDataUpdated, null);

  // start listening for the new project collection
  needsReplyMetricsSubscription?.cancel();
  needsReplyMetricsSubscription = platform.listenForMetrics(
    'projects/$selectedProject/$NEEDS_REPLY_METRICS_COLLECTION_KEY',
    (List<model.DocSnapshot> updatedMetrics) {
      if (signedInUser == null) {
        log.error("Receiving metrics when user is not logged it, something's wrong, abort.");
        return;
      }
      var updatedIds = updatedMetrics.map((m) => m.id).toSet();
      var updatedData = updatedMetrics.map((doc) => model.NeedsReplyData.fromSnapshot(doc)).toList();
      needsReplyDataList.removeWhere((d) => updatedIds.contains(d.docId));
      needsReplyDataList.addAll(updatedData);
      command(UIAction.needsReplyDataUpdated, null);
      checkNeedsReplyMetricsStale(updatedData);
    }
  );
}

void listenForDriverMetrics(String project, List<String> drivers) {
  // clear up the old data while the new data loads
  driversDataMap.clear();
  command(UIAction.driversDataUpdated, null);

  // start listening for the new project collection
  driverMetricsSubscriptions.forEach((subscription) => subscription?.cancel());
  driverMetricsSubscriptions.clear();
  for (var driver in drivers) {
    driversDataMap[driver] = [];
    driverMetricsSubscriptions.add(platform.listenForMetrics(
      'projects/$selectedProject/driver_metrics/$driver/metrics',
      (List<model.DocSnapshot> updatedMetrics) {
        if (signedInUser == null) {
          log.error("Receiving metrics when user is not logged it, something's wrong, abort.");
          return;
        }
        var updatedIds = updatedMetrics.map((m) => m.id).toSet();
        var updatedData = updatedMetrics.map((doc) => model.DriverData.fromSnapshot(doc)).toList();
        driversDataMap[driver].removeWhere((d) => updatedIds.contains(d.docId));
        driversDataMap[driver].addAll(updatedData);
        command(UIAction.driversDataUpdated, null);
      }
    ));
  }
}

void listenForSystemEvents(List<String> projects) {
  for (var project in projects) {
    systemEventsDataMap[project] = [];
    platform.listenForMetrics(
      'projects/$project/$SYSTEM_EVENTS_COLLECTION_KEY',
      (List<model.DocSnapshot> updatedEvents) {
        if (signedInUser == null) {
          log.error("Receiving system event data when user is not logged it, something's wrong, abort.");
          return;
        }
        var updatedIds = updatedEvents.map((m) => m.id).toSet();
        var updatedData = updatedEvents.map((doc) => model.SystemEventsData.fromSnapshot(doc)).toList();
        systemEventsDataMap[project].removeWhere((d) => updatedIds.contains(d.docId));
        systemEventsDataMap[project].addAll(updatedData);
        command(UIAction.systemEventsDataUpdated, null);
      }
    );
  }
}

void listenForSystemMetrics() {
  platform.listenForMetrics(
    '$SYSTEM_METRICS_ROOT_COLLECTION_KEY/$SYSTEM_METRICS_MACHINE_NAME/metrics',
    (List<model.DocSnapshot> updatedMetrics) {
      if (signedInUser == null) {
        log.error("Receiving system event data when user is not logged it, something's wrong, abort.");
        return;
      }
      var updatedIds = updatedMetrics.map((m) => m.id).toSet();
      var updatedData = updatedMetrics.map((doc) => model.SystemMetricsData.fromSnapshot(doc)).toList();
      systemMetricsDataList.removeWhere((d) => updatedIds.contains(d.docId));
      systemMetricsDataList.addAll(updatedData);
      command(UIAction.systemMetricsDataUpdated, null);
    }
  );
}

void listenForDirectoryMetrics() {
  platform.listenForMetrics(
    '$DIR_SIZE_METRICS_ROOT_COLLECTION_KEY/$SYSTEM_METRICS_MACHINE_NAME/metrics',
    (List<model.DocSnapshot> updatedMetrics) {
      if (signedInUser == null) {
        log.error("Receiving system event data when user is not logged it, something's wrong, abort.");
        return;
      }
      var updatedIds = updatedMetrics.map((m) => m.id).toSet();
      var updatedData = updatedMetrics.map((doc) => model.DirectorySizeMetricsData.fromSnapshot(doc)).toList();
      dirSizeMetricsDataList.removeWhere((d) => updatedIds.contains(d.docId));
      dirSizeMetricsDataList.addAll(updatedData);
      command(UIAction.dirSizeMetricsDataUpdated, null);
    }
  );
}

bool isProjectStale(model.NeedsReplyData projectData) {
  var now = new DateTime.now();
  int lastUpdateTimeDiff =  now.difference(projectData.datetime).inHours;

  if (lastUpdateTimeDiff >= 2) {
    return true;
  } else {
    return false;
  }
}

void setupProjectTimer(model.NeedsReplyData projectData, [bool stale = false]) {
  projectTimers[selectedProject]?.cancel();

  if (stale) {
    projectTimers[selectedProject] = null;
  } else {
    var timeToExecute =  projectData.datetime.add(Duration(hours: 2));
    var now = new DateTime.now();
    var duration = timeToExecute.difference(now);
    var timer = new Timer(duration, () {
      view.contentView.stale = true;
    });
    projectTimers[selectedProject] = timer;
  }
}

void checkNeedsReplyMetricsStale(List<model.NeedsReplyData> updatedData) {
  if (updatedData.isEmpty) {
    var selectedProjectTimer = projectTimers[selectedProject];
    selectedProjectTimer?.cancel();
    view.contentView.stale = false;
    return;
  }

  updatedData.sort((d1, d2) => d1.datetime.compareTo(d2.datetime));

  var latestProjectData = updatedData.last ?? null;

  if (latestProjectData != null) {

      if (isProjectStale(latestProjectData)) {
        setupProjectTimer(latestProjectData, true);
      } else {
        setupProjectTimer(latestProjectData);
      }
    }

  var selectedProjectTimer = projectTimers[selectedProject];
  if (selectedProjectTimer != null && selectedProjectTimer.isActive) {
    view.contentView.stale = false;
  } else {
    view.contentView.stale = true;
  }
}

void command(UIAction action, Data actionData) {
  switch (action) {
    /*** User */
    case UIAction.userSignedOut:
      signedInUser = null;
      view.authHeaderView.signOut();
      view.initSignedOutView();
      break;
    case UIAction.userSignedIn:
      UserData userData = actionData;
      signedInUser = new model.User()
        ..userName = userData.displayName
        ..userEmail = userData.email;
      view.authHeaderView.signIn(userData.displayName, userData.photoUrl);
      view.initSignedInView();
      initUI();
      break;
    case UIAction.signInButtonClicked:
      platform.signIn();
      break;
    case UIAction.signOutButtonClicked:
      platform.signOut();
      break;

    /*** Data */
    case UIAction.needsReplyDataUpdated:
      if (selectedTab == ChartType.conversation) {
        updateNeedsReplyCharts(filterNeedsReplyData(needsReplyDataList));
      }
      break;

    case UIAction.driversDataUpdated:
      if (selectedTab == ChartType.driver) {
        updateDriverCharts(filterDriversData(driversDataMap));
      }
      break;

    case UIAction.systemEventsDataUpdated:
      if (selectedTab == ChartType.system) {
        updateSystemEventsCharts(filterSystemEventsData(systemEventsDataMap));
      }
      break;

    case UIAction.systemMetricsDataUpdated:
      if (selectedTab == ChartType.system) {
        updateSystemMetricsCharts(filterSystemMetricsData(systemMetricsDataList));
      }
      break;

    case UIAction.dirSizeMetricsDataUpdated:
      break;

    /*** Filtering */
    case UIAction.tabSwitched:
      ChartTypeData tabData = actionData;
      selectedTab = tabData.chartType;
      view.contentView.toogleTabView(selectedTab);
      var periodFilterOptions = selectedTab == ChartType.driver ? hourFilters : dayFilters;
      view.ChartFiltersView().periodFilterOptions = periodFilterOptions;
      if (!periodFilterOptions.contains(selectedPeriodFilter)) {
        selectedPeriodFilter = selectedTab == ChartType.driver ? ChartPeriodFilters.hours1 : ChartPeriodFilters.days1;
      }
      view.ChartFiltersView().selectedPeriodFilter = selectedPeriodFilter;
      _resetDriverMetricFilters();
      view.contentView.setUrlFilters(selectedTab, selectedProject, selectedPeriodFilter);
      _updateChartsView();
      break;

    case UIAction.projectSelected:
      ProjectData projectData = actionData;
      selectedProject = projectData.project;
      listenForNeedsReplyMetrics(selectedProject);
      listenForDriverMetrics(selectedProject, DRIVERS);
      updateNeedsReplyCharts(filterNeedsReplyData(needsReplyDataList));
      updateSystemEventsCharts(filterSystemEventsData(systemEventsDataMap));
      view.contentView.clearDriverCharts();
      driverMetricsFilters.clear();
      updateDriverCharts(filterDriversData(driversDataMap));
      // skip updating the system metrics as these are project independent

      var selectedProjectTimer = projectTimers[selectedProject];
      if (selectedProjectTimer != null && selectedProjectTimer.isActive) {
        view.contentView.stale = false;
      } else {
        view.contentView.stale = true;
      }
      view.contentView.setUrlFilters(selectedTab, selectedProject, selectedPeriodFilter);
      break;

    case UIAction.chartsFiltered:
      ChartFilterData chartFilterData = actionData;
      selectedPeriodFilter = chartFilterData.periodFilter;
      view.contentView.setUrlFilters(selectedTab, selectedProject, selectedPeriodFilter);
      _updateChartsView();
      break;

    case UIAction.driverMetricsSelected:
      updateDriverCharts(filterDriversData(driversDataMap));
      break;
  }
}

void _resetDriverMetricFilters() {
  driverMetricsFilters.keys.forEach((driver) {
    var filters = driverMetricsFilters[driver] ;
    driverMetricsFilters[driver] = new Map.fromIterable(filters.keys, key: (metric) => metric, value: (_) => true);
  });
}

void _updateChartsView() {
  switch (selectedTab) {
    case ChartType.conversation:
      updateNeedsReplyCharts(filterNeedsReplyData(needsReplyDataList));
      break;
    case ChartType.driver:
      updateDriverCharts(filterDriversData(driversDataMap));
      break;
    case ChartType.system:
      updateSystemEventsCharts(filterSystemEventsData(systemEventsDataMap));
      updateSystemMetricsCharts(filterSystemMetricsData(systemMetricsDataList));
      break;
  }
}

List<model.NeedsReplyData> filterNeedsReplyData(List<model.NeedsReplyData> needsReplyData) {
  DateTime filterDate = getFilteredDate(selectedPeriodFilter);

  // early exit if there's no filtering needed
  if (filterDate == null) return needsReplyData;

  return needsReplyData.where((d) => d.datetime.isAfter(filterDate)).toList();
}

Map<String, List<model.DriverData>> filterDriversData(Map<String, List<model.DriverData>> driversData) {
  DateTime filterDate = getFilteredDate(selectedPeriodFilter);

  // early exit if there's no filtering needed
  if (filterDate == null) return driversData;

  Map<String, List<model.DriverData>> filteredDriversDataMap = {};

  driversData.keys.forEach((driver) {
    filteredDriversDataMap[driver] = driversData[driver].where((d) => d.datetime.isAfter(filterDate)).toList();
  });

  return filteredDriversDataMap;
}

List<model.SystemMetricsData> filterSystemMetricsData(List<model.SystemMetricsData> systemMetricsData) {
  DateTime filterDate = getFilteredDate(selectedPeriodFilter);

  // early exit if there's no filtering needed
  if (filterDate == null) return systemMetricsData;

  return systemMetricsDataList.where((d) => d.datetime.isAfter(filterDate)).toList();
}

Map<String, List<model.SystemEventsData>> filterSystemEventsData(Map<String, List<model.SystemEventsData>> systemEventsData) {
  DateTime filterDate = getFilteredDate(selectedPeriodFilter);

  // early exit if there's no filtering needed
  if (filterDate == null) return systemEventsData;

  Map<String, List<model.SystemEventsData>> filteredsystemEventsDataMap = {};
  systemEventsData.keys.forEach((project) {
    filteredsystemEventsDataMap[project] = systemEventsData[project].where((d) => d.timestamp.isAfter(filterDate)).toList();
  });
  return filteredsystemEventsDataMap;
}

void updateNeedsReplyCharts(List<model.NeedsReplyData> filteredNeedsReplyDataList) {
  var timeScaleUnit = dayFilters.contains(selectedPeriodFilter) ? 'hour' : 'day';

  DateTime xUpperLimitDateTime = getEndDateTimeForPeriod(view.ChartFiltersView().selectedPeriodFilter);
  DateTime xLowerLimitDateTime = getStartDateTimeForPeriod(view.ChartFiltersView().selectedPeriodFilter);

  Map<DateTime, int> data = new Map.fromIterable(filteredNeedsReplyDataList,
    key: (item) => (item as model.NeedsReplyData).datetime.toLocal(),
    value: (item) => (item as model.NeedsReplyData).needsReplyCount);
  view.contentView.needsReplyTimeseries.updateChart([data], timeScaleUnit: timeScaleUnit, xLowerLimit: xLowerLimitDateTime, xUpperLimit: xUpperLimitDateTime);

  data = new Map.fromIterable(filteredNeedsReplyDataList,
    key: (item) => (item as model.NeedsReplyData).datetime.toLocal(),
    value: (item) => (item as model.NeedsReplyData).needsReplyAndEscalateCount);
  view.contentView.needsReplyAndEscalateTimeseries.updateChart([data], timeScaleUnit: timeScaleUnit, xLowerLimit: xLowerLimitDateTime, xUpperLimit: xUpperLimitDateTime);

  data = new Map.fromIterable(filteredNeedsReplyDataList,
    key: (item) => (item as model.NeedsReplyData).datetime.toLocal(),
    value: (item) => (item as model.NeedsReplyData).needsReplyMoreThan24h);
  view.contentView.needsReplyMoreThan24hTimeseries.updateChart([data], timeScaleUnit: timeScaleUnit, xLowerLimit: xLowerLimitDateTime, xUpperLimit: xUpperLimitDateTime);

  data = new Map.fromIterable(filteredNeedsReplyDataList,
    key: (item) => (item as model.NeedsReplyData).datetime.toLocal(),
    value: (item) => (item as model.NeedsReplyData).needsReplyAndEscalateMoreThan24hCount);
  view.contentView.needsReplyAndEscalateMoreThan24hTimeseries.updateChart([data], timeScaleUnit: timeScaleUnit, xLowerLimit: xLowerLimitDateTime, xUpperLimit: xUpperLimitDateTime);

  if (filteredNeedsReplyDataList.isEmpty) {
    view.contentView.chartDataLastUpdateTime.text = 'No data to show for selected project and time range';
    view.contentView.needsReplyLatestValue.updateChart('-');
    view.contentView.needsReplyAndEscalateLatestValue.updateChart('-');
    view.contentView.needsReplyMoreThan24hLatestValue.updateChart('-');
    view.contentView.needsReplyAndEscalateMoreThan24hLatestValue.updateChart('-');
    // TODO: show a message on the timeseries charts saying that there's no data to show
    return;
  }

  DateTime latestDateTime = data.keys.reduce((dt1, dt2) => dt1.isAfter(dt2) ? dt1 : dt2);
  var latestData = filteredNeedsReplyDataList.firstWhere((d) => d.datetime.toLocal() == latestDateTime, orElse: () => null);

  view.contentView.needsReplyLatestValue.updateChart('${latestData.needsReplyCount}');
  view.contentView.needsReplyAndEscalateLatestValue.updateChart('${latestData.needsReplyAndEscalateCount}');
  view.contentView.needsReplyMoreThan24hLatestValue.updateChart('${latestData.needsReplyMoreThan24h}');
  view.contentView.needsReplyAndEscalateMoreThan24hLatestValue.updateChart('${latestData.needsReplyAndEscalateMoreThan24hCount}');

  view.contentView.needsReplyAgeHistogram.updateChart(latestData.needsReplyMessagesByDate);

  filteredNeedsReplyDataList.sort((a, b) => a.datetime.compareTo(b.datetime));
  DateTime lastUpdateTime = filteredNeedsReplyDataList.last.datetime;
  view.contentView.chartDataLastUpdateTime.text = 'Charts last updated on: ${lastUpdateTime.toLocal()}';
}

void updateDriverCharts(Map<String, List<model.DriverData>> filteredDriversDataMap) {
  var xLowerLimitDateTime = getStartDateTimeForPeriod(view.ChartFiltersView().selectedPeriodFilter);
  var xUpperLimitDateTime = getEndDateTimeForPeriod(view.ChartFiltersView().selectedPeriodFilter);

  view.contentView.createDriverCharts(filteredDriversDataMap);

  var previousFilters = new Map.from(driverMetricsFilters);
  if (filteredDriversDataMap.isNotEmpty) {
    DRIVERS.forEach((driver) {
      var metricNames = filteredDriversDataMap[driver].map((d) => d.metrics.keys).toSet().expand((m) => m).toSet();
      driverMetricsFilters[driver] =  Map.fromIterable(metricNames, key: (m) => m, value: (_)=> true);
  });
  }

  if (previousFilters.isNotEmpty) {
    driverMetricsFilters.forEach((driver, filters) {
      var updatedFilters = {}..addAll(filters)..addAll(previousFilters[driver]);
      var sortedFilters = Map<String, bool>.fromIterable(updatedFilters.keys.toList()..sort(), key: (m) => m, value: (m) => updatedFilters[m]);
      driverMetricsFilters[driver] = sortedFilters;
  });
  }

  filteredDriversDataMap.forEach((driverName, driverData) {
    var chart = view.contentView.driverCharts[driverName];

    var selectedMetrics = Map.fromEntries(driverMetricsFilters[driverName].entries.where((m) => m.value == true));

    List<String> metricNames = selectedMetrics.keys.toList()..sort();
    List<DateTime> datetimes = driverData.map((d) => d.datetime).toSet().toList()..sort();

    // Initialise the data to zero for all metrics and timestamps,
    // otherwise the bar chart doesn't work well.
    Map<String, Map<DateTime, num>> chartData = {};
    for (var metric in metricNames) {
      chartData[metric] = {};
      for (var datetime in datetimes) {
        chartData[metric][datetime.toLocal()] = 0;
      }
    }

    driverData.forEach((data) {
      data.metrics.forEach((metric, value) {
        if (metricNames.contains(metric)) {
          chartData[metric][data.datetime.toLocal()] = value;
        }
      });
    });
    chart.updateChart(chartData, timeScaleUnit: 'hour', xLowerLimit: xLowerLimitDateTime, xUpperLimit: xUpperLimitDateTime);
  });
  view.contentView.populateDriverChartsMetricsOptions();
}

void updateSystemEventsCharts(Map<String, List<model.SystemEventsData>> filteredsystemEventsDataMap) {
  List<String> systemNames = [];
  filteredsystemEventsDataMap.values.forEach((List<model.SystemEventsData> data) {
    systemNames.addAll(data.map((d) => d.systemName).toSet());
  });
  systemNames = systemNames.toSet().toList()..sort();
  view.contentView.createSystemEventsCharts(filteredsystemEventsDataMap);

  var xLowerLimitDateTime = getStartDateTimeForPeriod(view.ChartFiltersView().selectedPeriodFilter);
  var xUpperLimitDateTime = getEndDateTimeForPeriod(view.ChartFiltersView().selectedPeriodFilter);

  filteredsystemEventsDataMap.forEach((projectName, projectData) {
    var chart = view.contentView.systemEventsCharts[projectName];
    Map<String, Map<DateTime, num>> chartData = {};
    projectData.forEach((data) {
      chartData.putIfAbsent(data.systemName, () => {})[data.timestamp.toLocal()] =
          systemNames.indexOf(data.systemName) + 1;
    });
    chart.updateChart(chartData, yUpperLimit: systemNames.length + 1, xLowerLimit: xLowerLimitDateTime, xUpperLimit: xUpperLimitDateTime);
  });
}

void updateSystemMetricsCharts(List<model.SystemMetricsData> filteredSystemMetricsDataList) {
  int maxPercentage = 100;

  if (filteredSystemMetricsDataList.isEmpty) {
    view.contentView.cpuPercentSystemMetricsTimeseries.updateChart([{}], yUpperLimit: maxPercentage);
    view.contentView.diskUsageSystemMetricsTimeseries.updateChart([{}], yUpperLimit: maxPercentage);
    view.contentView.memoryUsageSystemMetricsTimeseries.updateChart([{}], yUpperLimit: maxPercentage);
    // TODO: show a message on each chart saying that there's no data to show
    return;
  }

  Map<DateTime, double> data = new Map.fromIterable(filteredSystemMetricsDataList,
      key: (item) => (item as model.SystemMetricsData).datetime.toLocal(),
      value: (item) => (item as model.SystemMetricsData).cpuPercent);
  view.contentView.cpuPercentSystemMetricsTimeseries.updateChart([data], yUpperLimit: maxPercentage);

  data = new Map.fromIterable(filteredSystemMetricsDataList,
      key: (item) => (item as model.SystemMetricsData).datetime.toLocal(),
      value: (item) => model.SystemMetricsData.sizeInGB((item as model.SystemMetricsData).diskUsage['used']));
  double maxDiskSpace = model.SystemMetricsData.sizeInGB(filteredSystemMetricsDataList.last.diskUsage['total']);
  view.contentView.diskUsageSystemMetricsTimeseries.updateChart([data], yUpperLimit: maxDiskSpace);

  data = new Map.fromIterable(filteredSystemMetricsDataList,
      key: (item) => (item as model.SystemMetricsData).datetime.toLocal(),
      value: (item) => model.SystemMetricsData.sizeInGB((item as model.SystemMetricsData).memoryUsage['used']));
  double maxMemory = model.SystemMetricsData.sizeInGB(filteredSystemMetricsDataList.last.memoryUsage['available']);
  view.contentView.memoryUsageSystemMetricsTimeseries.updateChart([data], yUpperLimit: maxMemory);
}

DateTime getEndDateTimeForPeriod(ChartPeriodFilters period) {
  var endDate;
  var now = DateTime.now();
  switch (period) {
    case ChartPeriodFilters.hours1:
    case ChartPeriodFilters.hours4:
    case ChartPeriodFilters.hours10:
      endDate = new DateTime(now.year, now.month, now.day, now.hour + 1);
      break;
    case ChartPeriodFilters.days1:
    case ChartPeriodFilters.days8:
    case ChartPeriodFilters.days15:
    case ChartPeriodFilters.month1:
    case ChartPeriodFilters.alltime:
      endDate = new DateTime(now.year, now.month, now.day + 1, 00);
      break;
  }
  return endDate;
}

DateTime getStartDateTimeForPeriod(ChartPeriodFilters period) {
  var startDate;
  var now = new DateTime.now();
  switch (period) {
    case ChartPeriodFilters.hours1:
      startDate = new DateTime(now.year, now.month, now.day, now.hour - 1);
      break;
    case ChartPeriodFilters.hours4:
      startDate = new DateTime(now.year, now.month, now.day, now.hour - 4);
      break;
    case ChartPeriodFilters.hours10:
      startDate = new DateTime(now.year, now.month, now.day, now.hour - 8);
      break;
    case ChartPeriodFilters.days1:
      startDate = new DateTime(now.year, now.month, now.day - 1, 00);
      break;
    case ChartPeriodFilters.days8:
      startDate = new DateTime(now.year, now.month, now.day - 8, 00);
      break;
    case ChartPeriodFilters.days15:
      startDate = new DateTime(now.year, now.month, now.day - 15, 00);
      break;
    case ChartPeriodFilters.month1:
      startDate = new DateTime(now.year, now.month - 1 , now.day, 00);
      break;
    case ChartPeriodFilters.alltime:
      startDate = null;
      break;
  }
  return startDate;
}

DateTime getFilteredDate(ChartPeriodFilters periodFilter) {
  DateTime now = new DateTime.now();
  DateTime filterDate;

  switch (periodFilter) {
    case ChartPeriodFilters.hours1:
      var diff = now.subtract(Duration(hours: 1));
      filterDate = new DateTime(diff.year, diff.month, diff.day, diff.hour);
      break;
    case ChartPeriodFilters.hours4:
      var diff = now.subtract(Duration(hours: 4));
      filterDate = new DateTime(diff.year, diff.month, diff.day, diff.hour);
      break;
    case ChartPeriodFilters.hours10:
      var diff = now.subtract(Duration(hours: 10));
      filterDate = new DateTime(diff.year, diff.month, diff.day, diff.hour);
      break;
    case ChartPeriodFilters.days1:
      var diff = now.subtract(Duration(days: 1));
      filterDate = new DateTime(diff.year, diff.month, diff.day);
      break;
    case ChartPeriodFilters.days8:
      var diff = now.subtract(Duration(days: 8));
      filterDate = new DateTime(diff.year, diff.month, diff.day);
      break;
    case ChartPeriodFilters.days15:
      var diff = now.subtract(Duration(days: 15));
      filterDate = new DateTime(diff.year, diff.month, diff.day);
      break;
    case ChartPeriodFilters.month1:
      var diff = now.subtract(Duration(days: 31));
      filterDate = new DateTime(diff.year, diff.month, diff.day);
      break;
    case ChartPeriodFilters.alltime:
      filterDate = null;
      break;
  }

  return filterDate;
}
