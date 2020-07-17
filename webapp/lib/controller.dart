library controller;

import 'dart:async';

import 'logger.dart';
import 'model.dart' as model;
import 'platform.dart' as platform;
import 'view.dart' as view;

Logger log = new Logger('controller.dart');

final NEEDS_REPLY_METRICS_COLLECTION_KEY = 'needs_reply';
final SYSTEM_EVENTS_COLLECTION_KEY = 'system_events';
final SYSTEM_METRICS_ROOT_COLLECTION_KEY = 'system_metrics';
final SYSTEM_METRICS_MACHINE_NAME = 'miranda';
final DIR_SIZE_METRICS_ROOT_COLLECTION_KEY = 'dir_size_metrics';

final PROJECTS = ['Lark_KK-Project-2020-COVID19', 'Lark_KK-Project-2020-COVID19-KE-URBAN', 
  'Lark_KK-Project-2020-COVID19-SOM-CC', 'Lark_KK-Project-2020-COVID19-SOM-IMAQAL', 'Lark_KK-Project-2020-COVID19-SOM-UNICEF'];

enum UIAction {
  userSignedIn,
  userSignedOut,
  signInButtonClicked,
  signOutButtonClicked,
  needsReplyDataUpdated,
  systemMetricsDataUpdated,
  dirSizeMetricsDataUpdated,
  systemEventsDataUpdated,
  projectSelected,
  chartsFiltered,
  tabSwitched,
}

enum ChartPeriodFilters {
  alltime,
  days1,
  days8,
  days15,
  month1,
}

enum ChartType {
  system,
  conversation
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
Map<String, List<model.SystemEventsData>> systemEventsDataMap;
List<model.SystemMetricsData> systemMetricsDataList;
List<model.DirectorySizeMetricsData> dirSizeMetricsDataList;

ChartType selectedTab;
String selectedProject;
ChartPeriodFilters selectedPeriodFilter;

model.User signedInUser;

Map<String, Timer> projectTimers = {};

void init() async {
  view.init();
  await platform.init();
}

void initUI() {
  needsReplyDataList = [];
  systemEventsDataMap = {};
  systemMetricsDataList = [];
  dirSizeMetricsDataList = [];

  selectedTab = view.contentView.getChartTypeUrlFilter() ?? ChartType.conversation;
  view.contentView.toogleTabView(selectedTab);

  selectedPeriodFilter = view.contentView.getChartPeriodFilter() ?? ChartPeriodFilters.alltime;
  view.ChartFiltersView().periodFilterOptions = ChartPeriodFilters.values;
  view.ChartFiltersView().selectedPeriodFilter = selectedPeriodFilter;

  selectedProject = view.contentView.getProjectFilter() ?? PROJECTS.first;

  view.contentView.setUrlFilters(selectedTab, selectedProject, selectedPeriodFilter);

  platform.listenForMetrics(
    '$selectedProject/$NEEDS_REPLY_METRICS_COLLECTION_KEY/metrics',
    (List<model.DocSnapshot> updatedMetrics) {
      if (signedInUser == null) {
        log.error("Receiving metrics when user is not logged it, something's wrong, abort.");
        return;
      }
      var updatedIds = updatedMetrics.map((m) => m.id).toSet();
      var updatedData = updatedMetrics.map((doc) => model.NeedsReplyData.fromSnapshot(doc)).toList();
      needsReplyDataList.removeWhere((d) => updatedIds.contains(d.docId));
      needsReplyDataList.addAll(updatedData);

      view.contentView.setUrlFilters(selectedTab, selectedProject, selectedPeriodFilter);
      view.contentView.projectSelectorView.projectOptions = PROJECTS;
      view.contentView.projectSelectorView.selectedProject = selectedProject;

      // Update charts
      command(UIAction.needsReplyDataUpdated, null);
      checkNeedsReplyMetricsStale(updatedData);
    }
  );

  for (var project in PROJECTS) {
    platform.listenForMetrics(
      '$project/$SYSTEM_EVENTS_COLLECTION_KEY/metrics',
      (List<model.DocSnapshot> updatedEvents) {
        if (signedInUser == null) {
          log.error("Receiving system event data when user is not logged it, something's wrong, abort.");
          return;
        }
        var updatedIds = updatedEvents.map((m) => m.id).toSet();
        var updatedData = updatedEvents.map((doc) => model.SystemEventsData.fromSnapshot(doc)).toList();
        systemEventsDataMap[project]?.removeWhere((d) => updatedIds.contains(d.docId));
        systemEventsDataMap[project] = updatedData;
        command(UIAction.systemEventsDataUpdated, null);
      }
    );
  }

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
  updatedData.sort((d1, d2) => d1.datetime.compareTo(d2.datetime));

  var selectedProjectName = selectedProject;
  var latestProjectData = updatedData.last ?? null;

  if (latestProjectData != null) {

      if (isProjectStale(latestProjectData)) {
        setupProjectTimer(latestProjectData, true);
      } else {
        setupProjectTimer(latestProjectData);
      }
    }

  var selectedProjectTimer = projectTimers[selectedProjectName];
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
      view.contentView.setUrlFilters(selectedTab, selectedProject, selectedPeriodFilter);
      if (selectedTab == ChartType.conversation) {
        updateNeedsReplyCharts(filterNeedsReplyData(needsReplyDataList));
      } else if (selectedTab == ChartType.system) {
        updateSystemEventsCharts(filterSystemEventsData(systemEventsDataMap));
        updateSystemMetricsCharts(filterSystemMetricsData(systemMetricsDataList));
      }
      break;

    case UIAction.projectSelected:
      ProjectData projectData = actionData;
      selectedProject = projectData.project;
      updateNeedsReplyCharts(filterNeedsReplyData(needsReplyDataList));
      updateSystemEventsCharts(filterSystemEventsData(systemEventsDataMap));
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
      if (selectedTab == ChartType.conversation) {
        updateNeedsReplyCharts(filterNeedsReplyData(needsReplyDataList));
      } else if (selectedTab == ChartType.system) {
        updateSystemEventsCharts(filterSystemEventsData(systemEventsDataMap));
        updateSystemMetricsCharts(filterSystemMetricsData(systemMetricsDataList));
      }
      break;
  }
}

List<model.NeedsReplyData> filterNeedsReplyData(List<model.NeedsReplyData> needsReplyData) {
  List<model.NeedsReplyData> filteredNeedsReplyData = [];

  DateTime filterDate = getFilteredDate(selectedPeriodFilter);
  if (filterDate != null) {
    filteredNeedsReplyData = needsReplyData.where((d) => d.datetime.isAfter(filterDate)).toList();
  } else {
    filteredNeedsReplyData = needsReplyData;
  }
  return filteredNeedsReplyData;
}

List<model.SystemMetricsData> filterSystemMetricsData(List<model.SystemMetricsData> systemMetricsData) {
  List<model.SystemMetricsData> filteredSystemMetricsDataList = [];

  DateTime filterDate = getFilteredDate(selectedPeriodFilter);
  if (filterDate != null) {
    filteredSystemMetricsDataList = systemMetricsDataList.where((d) =>
        d.datetime.isAfter(filterDate)).toList();
  } else {
    filteredSystemMetricsDataList = systemMetricsDataList;
  }
  return filteredSystemMetricsDataList;
}

Map<String, List<model.SystemEventsData>> filterSystemEventsData(Map<String, List<model.SystemEventsData>> systemEventsData) {
  var filteredsystemEventsDataMap = {};

  DateTime filterDate = getFilteredDate(selectedPeriodFilter);

  systemEventsData.keys.forEach((project) {
    if (filterDate != null) {
      filteredsystemEventsDataMap[project] = systemEventsData[project].where((d) => d.timestamp.isAfter(filterDate)).toList();
    } else {
      filteredsystemEventsDataMap = systemEventsData;
    }
  });
  return filteredsystemEventsDataMap;
}

void updateNeedsReplyCharts(List<model.NeedsReplyData> filteredNeedsReplyDataList) {
  var timeScaleUnit = selectedPeriodFilter == ChartPeriodFilters.days1 ? 'hour' : 'day';

  DateTime xUpperLimitDateTime = getEndDateTimeForPeriod();
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

  DateTime latestDateTime = data.keys.reduce((dt1, dt2) => dt1.isAfter(dt2) ? dt1 : dt2);
  var latestData = filteredNeedsReplyDataList.firstWhere((d) => d.datetime.toLocal() == latestDateTime, orElse: () => null);

  view.contentView.needsReplyLatestValue.updateChart('${latestData.needsReplyCount}');
  view.contentView.needsReplyAndEscalateLatestValue.updateChart('${latestData.needsReplyAndEscalateCount}');
  view.contentView.needsReplyMoreThan24hLatestValue.updateChart('${latestData.needsReplyMoreThan24h}');
  view.contentView.needsReplyAndEscalateMoreThan24hLatestValue.updateChart('${latestData.needsReplyAndEscalateMoreThan24hCount}');

  view.contentView.needsReplyAgeHistogram.updateChart(latestData.needsReplyMessagesByDate);

  var selectedNeedsReplyEntries = filteredNeedsReplyDataList;
  selectedNeedsReplyEntries.sort((a, b) => a.datetime.compareTo(b.datetime));
  DateTime lastUpdateTime = selectedNeedsReplyEntries.last.datetime;
  view.contentView.chartDataLastUpdateTime.text = 'Charts last updated on: ${lastUpdateTime.toLocal()}';
}

void updateSystemEventsCharts(Map<String, List<model.SystemEventsData>> filteredsystemEventsDataMap) {
  List<String> systemNames = [];
  filteredsystemEventsDataMap.values.forEach((List<model.SystemEventsData> data) {
    systemNames.addAll(data.map((d) => d.systemName).toSet());
  });
  systemNames = systemNames.toSet().toList()..sort();
  view.contentView.createSystemEventsCharts(filteredsystemEventsDataMap);

  var xLowerLimitDateTime = getStartDateTimeForPeriod(view.ChartFiltersView().selectedPeriodFilter);
  var xUpperLimitDateTime = getEndDateTimeForPeriod();

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
  Map<DateTime, double> data = new Map.fromIterable(filteredSystemMetricsDataList,
      key: (item) => (item as model.SystemMetricsData).datetime.toLocal(),
      value: (item) => (item as model.SystemMetricsData).cpuPercent);
  int maxPercentage = 100;
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

DateTime getEndDateTimeForPeriod() {
  var now = DateTime.now();
  return new DateTime(now.year, now.month, now.day + 1, 00);
}

DateTime getStartDateTimeForPeriod(ChartPeriodFilters period) {
  var startDate;
  var now = new DateTime.now();
  switch (period) {
    case ChartPeriodFilters.alltime:
      startDate = null;
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
  }
  return startDate;
}

DateTime getFilteredDate(ChartPeriodFilters periodFilter) {
  DateTime now = new DateTime.now();
  DateTime filterDate;

  switch (periodFilter) {
    case ChartPeriodFilters.alltime:
      filterDate = null;
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
  }

  return filterDate;
}
