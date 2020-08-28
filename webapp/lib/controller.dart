library controller;

import 'dart:async';

import 'logger.dart';
import 'model.dart' as model;
import 'platform.dart' as platform;
import 'view.dart' as view;

Logger log = new Logger('controller.dart');

final ESCALATE_METRICS_COLLECTION_KEY = 'escalate_metrics';
final SYSTEM_EVENTS_COLLECTION_KEY = 'system_events';
final SYSTEM_METRICS_ROOT_COLLECTION_KEY = 'systems';
final SYSTEM_METRICS_MACHINE_NAME = 'miranda';
final DIR_SIZE_METRICS_ROOT_COLLECTION_KEY = 'dir_size_metrics';

enum UIAction {
  userSignedIn,
  userSignedOut,
  signInButtonClicked,
  signOutButtonClicked,
  escalateMetricsDataUpdated,
  driversDataUpdated,
  systemMetricsDataUpdated,
  dirSizeMetricsDataUpdated,
  systemEventsDataUpdated,
  projectSelected,
  chartsFiltered,
  tabSwitched,
  driverMetricsSelected,
  driverYUpperLimitSet,
  driverXLowerLimitSet,
  driverXUpperLimitSet
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

  @override
  String toString() {
    return "ChartFilterData($periodFilter)";
  }
}

class ChartTypeData extends Data {
  ChartType chartType;
  ChartTypeData(this.chartType);

  @override
  String toString() {
    return "ChartTypeData($chartType)";
  }
}

class ProjectData extends Data {
  String project;
  ProjectData(this.project);

  @override
  String toString() {
    return "ProjectData($project)";
  }
}

class UserData extends Data {
  String displayName;
  String email;
  String photoUrl;
  UserData(this.displayName, this.email, this.photoUrl);

  @override
  String toString() {
    return "UserData($displayName, $email, $photoUrl)";
  }
}

List<String> PROJECTS;
Map<String, List<String>> DRIVERS;

model.EscalateMetricsData escalateMetricsData;
Map<String, List<model.DriverData>> driversDataMap;
Map<String, List<model.SystemEventsData>> systemEventsDataMap;
List<model.SystemMetricsData> systemMetricsDataList;
List<model.DirectorySizeMetricsData> dirSizeMetricsDataList;

ChartType selectedTab;
String selectedProject;
ChartPeriodFilters selectedPeriodFilter;
Map<String, Map<String, bool>> driverMetricsFilters;
Map<String, Map<String, DateTime>> driverXLimitFilters;
Map<String, num> driverYUpperLimitFilters;

model.User signedInUser;

Map<String, Timer> watchdogTimers = {};

StreamSubscription escalateMetricsSubscription;
List<StreamSubscription> driverMetricsSubscriptions = [];
List<StreamSubscription> systemEventsSubscriptions = [];
StreamSubscription systemMetricsSubscription;

void init() async {
  view.init();
  await platform.init();
}

void initUI() async{
  PROJECTS = await platform.activeProjects;
  DRIVERS = await platform.projectsDrivers;

  driversDataMap = {};
  systemEventsDataMap = {};
  systemMetricsDataList = [];
  dirSizeMetricsDataList = [];
  driverMetricsFilters = {};
  driverXLimitFilters = {};
  driverYUpperLimitFilters = {};

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

  //selectedTab already initialized at this point. Doing this for the purpose of pulling data from firestore
  command(UIAction.tabSwitched, new ChartTypeData(selectedTab));
}

void listenForEscalateMetrics(String project) {
  // clear up the old data while the new data loads
  escalateMetricsData = null;
  command(UIAction.escalateMetricsDataUpdated, null);
  view.contentView.toggleChartLoadingState(ChartType.conversation, true);

  // start listening for the new project collection
  escalateMetricsSubscription?.cancel();
  escalateMetricsSubscription = platform.listenForMetrics(
    'projects/$project/$ESCALATE_METRICS_COLLECTION_KEY',
    'escalate_analytics',
    null,
    'datetime',
    (List<model.DocSnapshot> updatedMetrics) {
      if (signedInUser == null) {
        log.error("Receiving metrics when user is not logged it, something's wrong, abort.");
        return;
      }
      escalateMetricsData = updatedMetrics.map((doc) => model.EscalateMetricsData.fromSnapshot(doc)).first;
      command(UIAction.escalateMetricsDataUpdated, null);
      view.contentView.toggleChartLoadingState(ChartType.conversation, false);
    }
  );
}

void listenForDriverMetrics(String project, List<String> drivers) {
  // clear up the old data while the new data loads
  driversDataMap.clear();
  command(UIAction.driversDataUpdated, null);
  view.contentView.toggleChartLoadingState(ChartType.driver, true);

  // start listening for the new project collection
  driverMetricsSubscriptions.forEach((subscription) => subscription?.cancel());
  driverMetricsSubscriptions.clear();
  for (var driver in drivers) {
    driversDataMap[driver] = [];
    driverMetricsSubscriptions.add(platform.listenForMetrics(
      'projects/$project/driver_metrics/$driver/metrics',
      null,
      getFilteredDate(selectedPeriodFilter),
      'datetime',
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
        view.contentView.toggleChartLoadingState(ChartType.driver, false);
      }
    ));
  }
}

void listenForSystemEvents(List<String> projects) {
  // clear up the old data while the new data loads
  systemEventsDataMap.clear();
  command(UIAction.systemEventsDataUpdated, null);
  view.contentView.toggleChartLoadingState(ChartType.system, true, true);

  // start listening for the new project collection
  systemEventsSubscriptions.forEach((subscription) => subscription?.cancel());
  systemEventsSubscriptions.clear();
  for (var project in projects) {
    systemEventsDataMap[project] = [];
    systemEventsSubscriptions.add(platform.listenForMetrics(
      'projects/$project/$SYSTEM_EVENTS_COLLECTION_KEY',
      null,
      getFilteredDate(selectedPeriodFilter),
      'timestamp',
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
        view.contentView.toggleChartLoadingState(ChartType.system, false, true);
      }
    ));
  }
}

void listenForSystemMetrics() {
  // clear up the old data while the new data loads
  systemMetricsDataList.clear();
  command(UIAction.systemMetricsDataUpdated, null);
  view.contentView.toggleChartLoadingState(ChartType.system, true);

  // start listening for the new project collection
  systemMetricsSubscription?.cancel();
  systemMetricsSubscription = platform.listenForMetrics(
    '$SYSTEM_METRICS_ROOT_COLLECTION_KEY/$SYSTEM_METRICS_MACHINE_NAME/metrics',
    null,
    getFilteredDate(selectedPeriodFilter),
    'datetime',
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
      checkSystemMetricsStale(updatedData);
      view.contentView.toggleChartLoadingState(ChartType.system, false);
    }
  );
}

void listenForDirectoryMetrics() {
  platform.listenForMetrics(
    '$DIR_SIZE_METRICS_ROOT_COLLECTION_KEY/$SYSTEM_METRICS_MACHINE_NAME/metrics',
    null,
    getFilteredDate(selectedPeriodFilter),
    'datetime',
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

bool isDataStale(Object projectData) {
  var data;
  if (projectData is model.SystemMetricsData) {
    data = projectData as model.SystemMetricsData;
  } else {
    throw new model.DataModelNotSupported('Data object of type "${projectData.runtimeType}" not supported for staleness monitoring');
  }

  var now = new DateTime.now();
  int lastUpdateTimeDiff =  now.difference(data.datetime).inHours;

  if (lastUpdateTimeDiff >= 2) {
    return true;
  } else {
    return false;
  }
}

String getWatchdogTimerKey(Object data) {
  if (data is model.SystemMetricsData) {
    return SYSTEM_METRICS_ROOT_COLLECTION_KEY;
  } else {
    throw new model.DataModelNotSupported('Data object of type "${data.runtimeType}" not supported for staleness monitoring');
  }
}

void setupWatchdogTimer(Object latestData, [bool stale = false]) {
  var data;
  if (latestData is model.SystemMetricsData) {
    data = latestData as model.SystemMetricsData;
  } else {
    throw new model.DataModelNotSupported('Data object of type "${latestData.runtimeType}" not supported for staleness monitoring');
  }

  watchdogTimers[getWatchdogTimerKey(data)]?.cancel();

  if (stale) {
    watchdogTimers[getWatchdogTimerKey(data)] = null;
  } else {
    var timeToExecute =  data.datetime.add(Duration(minutes: 30));
    var now = new DateTime.now();
    var duration = timeToExecute.difference(now);
    var timer = new Timer(duration, () {
      view.contentView.setStale(SYSTEM_METRICS_ROOT_COLLECTION_KEY, true);
    });
    watchdogTimers[getWatchdogTimerKey(data)] = timer;
  }
}

void checkSystemMetricsStale(List<model.SystemMetricsData> updatedData) {
  if (updatedData.isEmpty) {
    var selectedTimer = watchdogTimers[SYSTEM_METRICS_ROOT_COLLECTION_KEY];
    selectedTimer?.cancel();
    view.contentView.setStale(SYSTEM_METRICS_ROOT_COLLECTION_KEY, false);
    return;
  }

  updatedData.sort((d1, d2) => d1.datetime.compareTo(d2.datetime));
  var latestData = updatedData.last;

  setupWatchdogTimer(latestData, isDataStale(latestData));

  var timer = watchdogTimers[SYSTEM_METRICS_ROOT_COLLECTION_KEY];
  if (timer != null && timer.isActive) {
    view.contentView.setStale(SYSTEM_METRICS_ROOT_COLLECTION_KEY, false);
  } else {
    view.contentView.setStale(SYSTEM_METRICS_ROOT_COLLECTION_KEY, true);
  }
}

void command(UIAction action, Data actionData) {
  log.verbose('command => $action : $actionData');
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
    case UIAction.escalateMetricsDataUpdated:
      if (selectedTab == ChartType.conversation) {
        updateEscalateMetricsCharts(escalateMetricsData);
      }
      break;

    case UIAction.driversDataUpdated:
      if (selectedTab == ChartType.driver) {
        updateDriverCharts(driversDataMap);
      }
      break;

    case UIAction.systemEventsDataUpdated:
      if (selectedTab == ChartType.system) {
        updateSystemEventsCharts(systemEventsDataMap);
      }
      break;

    case UIAction.systemMetricsDataUpdated:
      if (selectedTab == ChartType.system) {
        updateSystemMetricsCharts(systemMetricsDataList);
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
      driverXLimitFilters.clear();
      driverYUpperLimitFilters.clear();
      view.contentView.setUrlFilters(selectedTab, selectedProject, selectedPeriodFilter);
      _updateChartsView(true);
      break;

    case UIAction.projectSelected:
      ProjectData projectData = actionData;
      selectedProject = projectData.project;
      view.contentView.clearDriverCharts();
      driverMetricsFilters.clear();
      driverXLimitFilters.clear();
      driverYUpperLimitFilters.clear();
      _updateChartsView();
      view.contentView.setUrlFilters(selectedTab, selectedProject, selectedPeriodFilter);
      break;

    case UIAction.chartsFiltered:
      ChartFilterData chartFilterData = actionData;
      selectedPeriodFilter = chartFilterData.periodFilter;
      view.contentView.setUrlFilters(selectedTab, selectedProject, selectedPeriodFilter);
      driverXLimitFilters.clear();
      driverYUpperLimitFilters.clear();
      _updateChartsView(true);
      break;

    case UIAction.driverMetricsSelected:
      updateDriverCharts(driversDataMap);
      break;

    case UIAction.driverYUpperLimitSet:
      updateDriverCharts(driversDataMap);
      break;

    case UIAction.driverXLowerLimitSet:
      updateDriverCharts(driversDataMap);
      break;

    case UIAction.driverXUpperLimitSet:
      updateDriverCharts(driversDataMap);
      break;
  }
}

void _resetDriverMetricFilters() {
  driverMetricsFilters.keys.forEach((driver) {
    var filters = driverMetricsFilters[driver] ;
    driverMetricsFilters[driver] = new Map.fromIterable(filters.keys, key: (metric) => metric, value: (_) => true);
  });
}

void _updateChartsView([skipUpdateSystemMetricsChart = false]) {
  switch (selectedTab) {
    case ChartType.conversation:
      listenForEscalateMetrics(selectedProject);
      break;
    case ChartType.driver:
      listenForDriverMetrics(selectedProject, DRIVERS[selectedProject]);
      break;
    case ChartType.system:
      listenForSystemEvents(PROJECTS);
      if (skipUpdateSystemMetricsChart) {
        listenForSystemMetrics();
      }
      break;
  }
}

void updateEscalateMetricsCharts(model.EscalateMetricsData filteredEscalateMetricsData) {
  if (filteredEscalateMetricsData == null) {
    view.contentView.conversationsCount.updateChart('-');
    view.contentView.escalateConversations.updateChart('-');
    view.contentView.escalateConversationsOurTurn.updateChart('-');
    return;
  }

  view.contentView.conversationsCount.updateChart('${filteredEscalateMetricsData.conversationsCount}');
  view.contentView.escalateConversations.updateChart('${filteredEscalateMetricsData.escalateConversations}');
  view.contentView.escalateConversationsOurTurn.updateChart('${filteredEscalateMetricsData.escalateConversationsOurTurn}');
}

void updateDriverCharts(Map<String, List<model.DriverData>> filteredDriversDataMap) {
  var xLowerLimitDateTime= getStartDateTimeForPeriod(view.ChartFiltersView().selectedPeriodFilter);
  var xUpperLimitDateTime = getEndDateTimeForPeriod(view.ChartFiltersView().selectedPeriodFilter);

  view.contentView.createDriverCharts(filteredDriversDataMap);

  var previousFilters = new Map.from(driverMetricsFilters);
  if (filteredDriversDataMap.isNotEmpty) {
    DRIVERS[selectedProject].forEach((driver) {
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

    if (driverXLimitFilters[driverName] != null && driverXLimitFilters[driverName].containsKey('min')) {
      xLowerLimitDateTime = driverXLimitFilters[driverName]['min'];
    } else {
      view.contentView.setDriverChartsXAxisFilterMin(driverName, xLowerLimitDateTime, xUpperLimitDateTime);
    }

    if (driverXLimitFilters[driverName] != null && driverXLimitFilters[driverName]['max'] != null) {
      xUpperLimitDateTime = driverXLimitFilters[driverName]['max'];
    } else {
      view.contentView.setDriverChartsXAxisFilterMax(driverName, xLowerLimitDateTime, xUpperLimitDateTime);
    }

    var yUpperLimit = 0;
    if (driverYUpperLimitFilters[driverName] != null) {
      yUpperLimit = driverYUpperLimitFilters[driverName];
    } else {
      metricNames.forEach((metric) {
        var metricData = chartData[metric];
        if (metricData.isNotEmpty) {
          var maxY = (metricData.values.toList()..sort()).last;
          yUpperLimit += maxY;
        }
      });
      view.contentView.setDriverChartsYAxisFilterMax(driverName, yUpperLimit);
    }

    if (yUpperLimit == 0) yUpperLimit = null;
    chart.updateChart(chartData, timeScaleUnit: 'hour', xLowerLimit: xLowerLimitDateTime, xUpperLimit: xUpperLimitDateTime, yUpperLimit: yUpperLimit);
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
  double maxMemory = model.SystemMetricsData.sizeInGB(filteredSystemMetricsDataList.last.memoryUsage['total']);
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
      startDate = new DateTime(now.year, now.month, now.day, now.hour - 10);
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
