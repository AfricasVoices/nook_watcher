library controller;

import 'dart:async';

import 'logger.dart';
import 'model.dart' as model;
import 'platform.dart' as platform;
import 'view.dart' as view;

Logger log = new Logger('controller.dart');

final NEEDS_REPLY_METRICS_ROOT_COLLECTION_KEY = 'needs_reply_metrics';
final SYSTEM_EVENTS_ROOT_COLLECTION_KEY = 'system_events';
final SYSTEM_METRICS_ROOT_COLLECTION_KEY = 'pipeline_system_metrics';
final DIR_SIZE_METRICS_ROOT_COLLECTION_KEY = 'dir_size_metrics';

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


Set<String> projectList;
Set<String> systemEventsProjects;
List<model.NeedsReplyData> needsReplyDataList;
List<model.SystemEventsData> systemEventsDataList;
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
  projectList = {};
  systemEventsProjects = {};
  needsReplyDataList = [];
  systemEventsDataList = [];
  systemMetricsDataList = [];
  dirSizeMetricsDataList = [];

  selectedTab = view.contentView.getChartTypeUrlFilter() ?? ChartType.conversation;
  view.contentView.toogleTabView(selectedTab);

  selectedPeriodFilter = view.contentView.getChartPeriodFilter() ?? ChartPeriodFilters.alltime;
  view.ChartFiltersView().periodFilterOptions = ChartPeriodFilters.values;
  view.ChartFiltersView().selectedPeriodFilter = selectedPeriodFilter;

  selectedProject = view.contentView.getProjectFilter();

  view.contentView.setUrlFilters(selectedTab, selectedProject, selectedPeriodFilter);

  platform.listenForMetrics(
    NEEDS_REPLY_METRICS_ROOT_COLLECTION_KEY,
    (List<model.DocSnapshot> updatedMetrics) {
      if (signedInUser == null) {
        log.error("Receiving metrics when user is not logged it, something's wrong, abort.");
        return;
      }
      var updatedIds = updatedMetrics.map((m) => m.id).toSet();
      var updatedData = updatedMetrics.map((doc) => model.NeedsReplyData.fromSnapshot(doc)).toList();
      needsReplyDataList.removeWhere((d) => updatedIds.contains(d.docId));
      needsReplyDataList.addAll(updatedData);

      // Update project list and selected project if it's the first time
      projectList.addAll(updatedData.map((m) => m.project).toSet());
      if (selectedProject == null || !projectList.contains(selectedProject)) {
        selectedProject = projectList.first;
      }
      view.contentView.setUrlFilters(selectedTab, selectedProject, selectedPeriodFilter);
      view.contentView.projectSelectorView.projectOptions = projectList.toList();
      view.contentView.projectSelectorView.selectedProject = selectedProject;

      // Update charts
      command(UIAction.needsReplyDataUpdated, null);
      checkNeedsReplyMetricsStale(updatedData);
    }
  );

  platform.listenForMetrics(
    SYSTEM_EVENTS_ROOT_COLLECTION_KEY,
    (List<model.DocSnapshot> updatedEvents) {
      if (signedInUser == null) {
        log.error("Receiving system event data when user is not logged it, something's wrong, abort.");
        return;
      }
      var updatedIds = updatedEvents.map((m) => m.id).toSet();
      var updatedData = updatedEvents.map((doc) => model.SystemEventsData.fromSnapshot(doc)).toList();
      systemEventsDataList.removeWhere((d) => updatedIds.contains(d.docId));
      systemEventsDataList.addAll(updatedData);
      command(UIAction.systemEventsDataUpdated, null);
    }
  );

  platform.listenForMetrics(
    SYSTEM_METRICS_ROOT_COLLECTION_KEY,
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
    DIR_SIZE_METRICS_ROOT_COLLECTION_KEY,
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

Map<String, model.NeedsReplyData> getLatestDataForProjects(List<model.NeedsReplyData> updatedData) {
  Map<String, model.NeedsReplyData> latestProjectData = {};

  for (var project in projectList) {
    var data = updatedData.where((data) => data.project == project).toList();

    if (data.isEmpty) {
      latestProjectData[project] = null;
    } else {
      latestProjectData[project] = data.last;
    }
  }
  return latestProjectData;
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
  projectTimers[projectData.project]?.cancel();

  if (stale) {
    projectTimers[projectData.project] = null;
  } else {
    var timeToExecute =  projectData.datetime.add(Duration(hours: 2));
    var now = new DateTime.now();
    var duration = timeToExecute.difference(now);
    var timer = new Timer(duration, () {
      if (projectData.project == selectedProject) {
        view.contentView.stale = true;
      }
    });
    projectTimers[projectData.project] = timer;
  }
}

void checkNeedsReplyMetricsStale(List<model.NeedsReplyData> updatedData) {
  updatedData.sort((d1, d2) => d1.datetime.compareTo(d2.datetime));

  var selectedProjectName = selectedProject;
  Map<String, model.NeedsReplyData> latestDataPerProject = getLatestDataForProjects(updatedData);

  for (var project in latestDataPerProject.keys) {
    var projectData = latestDataPerProject[project];

    if (projectData != null) {

      if (isProjectStale(projectData)) {
        setupProjectTimer(projectData, true);
      } else {
        setupProjectTimer(projectData);
      }
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
      updateNeedsReplyCharts(filterNeedsReplyData(needsReplyDataList));
      break;

    case UIAction.systemEventsDataUpdated:
      updateSystemEventsCharts(filterSystemEventsData(systemEventsDataList));
      break;

    case UIAction.systemMetricsDataUpdated:
      updateSystemMetricsCharts(filterSystemMetricsData(systemMetricsDataList));
      break;

    case UIAction.dirSizeMetricsDataUpdated:
      break;

    /*** Filtering */
    case UIAction.tabSwitched:
      ChartTypeData tabData = actionData;
      selectedTab = tabData.chartType;
      view.contentView.toogleTabView(selectedTab);
      view.contentView.setUrlFilters(selectedTab, selectedProject, selectedPeriodFilter);
      break;

    case UIAction.projectSelected:
      ProjectData projectData = actionData;
      selectedProject = projectData.project;
      updateNeedsReplyCharts(filterNeedsReplyData(needsReplyDataList));
      updateSystemEventsCharts(filterSystemEventsData(systemEventsDataList));
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
      updateNeedsReplyCharts(filterNeedsReplyData(needsReplyDataList));
      updateSystemEventsCharts(filterSystemEventsData(systemEventsDataList));
      updateSystemMetricsCharts(filterSystemMetricsData(systemMetricsDataList));
      break;
  }
}

List<model.NeedsReplyData> filterNeedsReplyData(List<model.NeedsReplyData> needsReplyData) {
  List<model.NeedsReplyData> filteredNeedsReplyData = [];

  DateTime filterDate = getFilteredDate(selectedPeriodFilter);
  if (filterDate != null) {
    filteredNeedsReplyData = needsReplyData.where((d) =>
        d.project == selectedProject &&
        d.datetime.isAfter(filterDate)).toList();
  } else {
    filteredNeedsReplyData = needsReplyData.where((d) =>
        d.project == selectedProject).toList();
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

List<model.SystemEventsData> filterSystemEventsData(List<model.SystemEventsData> systemEventsData) {
  systemEventsProjects = systemEventsData.map((d) => d.project).toSet();
  List<model.SystemEventsData> filteredSystemEventsDataList = [];

  DateTime filterDate = getFilteredDate(selectedPeriodFilter);

  if (filterDate != null) {
    filteredSystemEventsDataList = systemEventsData.where((d) => d.timestamp.isAfter(filterDate)).toList();
  } else {
    filteredSystemEventsDataList = systemEventsData;
  }
  return filteredSystemEventsDataList;
}

void updateNeedsReplyCharts(List<model.NeedsReplyData> filteredNeedsReplyDataList) {
  var timeScaleUnit = selectedPeriodFilter == ChartPeriodFilters.days1 ? 'hour' : 'day';

  Map<DateTime, int> data = new Map.fromIterable(filteredNeedsReplyDataList,
    key: (item) => (item as model.NeedsReplyData).datetime.toLocal(),
    value: (item) => (item as model.NeedsReplyData).needsReplyCount);
  DateTime xUpperLimitDateTime = getEndDateTimeForPeriod();
  view.contentView.needsReplyTimeseries.updateChart([data], timeScaleUnit: timeScaleUnit, xUpperLimit: xUpperLimitDateTime);

  data = new Map.fromIterable(filteredNeedsReplyDataList,
    key: (item) => (item as model.NeedsReplyData).datetime.toLocal(),
    value: (item) => (item as model.NeedsReplyData).needsReplyAndEscalateCount);
  xUpperLimitDateTime = getEndDateTimeForPeriod();
  view.contentView.needsReplyAndEscalateTimeseries.updateChart([data], timeScaleUnit: timeScaleUnit, xUpperLimit: xUpperLimitDateTime);

  data = new Map.fromIterable(filteredNeedsReplyDataList,
    key: (item) => (item as model.NeedsReplyData).datetime.toLocal(),
    value: (item) => (item as model.NeedsReplyData).needsReplyMoreThan24h);
  xUpperLimitDateTime = getEndDateTimeForPeriod();
  view.contentView.needsReplyMoreThan24hTimeseries.updateChart([data], timeScaleUnit: timeScaleUnit, xUpperLimit: xUpperLimitDateTime);

  data = new Map.fromIterable(filteredNeedsReplyDataList,
    key: (item) => (item as model.NeedsReplyData).datetime.toLocal(),
    value: (item) => (item as model.NeedsReplyData).needsReplyAndEscalateMoreThan24hCount);
  xUpperLimitDateTime = getEndDateTimeForPeriod();
  view.contentView.needsReplyAndEscalateMoreThan24hTimeseries.updateChart([data], timeScaleUnit: timeScaleUnit, xUpperLimit: xUpperLimitDateTime);

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

void updateSystemEventsCharts(List<model.SystemEventsData> filteredSystemEventsDataList) {
  List<String> systemNameProjects = filteredSystemEventsDataList.map((d) => d.systemName).toSet().toList()..sort();
  Map<String, List<model.SystemEventsData>> systemEventsProjectsData = {};

  systemEventsProjects.forEach((project) =>
      systemEventsProjectsData[project] = filteredSystemEventsDataList.where((d) => d.project == project).toList());
  view.contentView.createSystemEventsCharts(systemEventsProjectsData);

  var xLowerLimitDateTime = getStartDateTimeForPeriod(view.ChartFiltersView().selectedPeriodFilter);
  var xUpperLimitDateTime = getEndDateTimeForPeriod();

  systemEventsProjectsData.forEach((projectName, projectData) {
    var chart = view.contentView.systemEventsCharts[projectName];
    Map<String, Map<DateTime, num>> chartData = {};
    projectData.forEach((data) {
      chartData.putIfAbsent(data.systemName, () => {})[data.timestamp.toLocal()] =
          systemNameProjects.indexOf(data.systemName) + 1;
    });
    chart.updateChart(chartData, upperLimit: systemNameProjects.length + 1, xLowerLimit: xLowerLimitDateTime, xUpperLimit: xUpperLimitDateTime);
  });
}

void updateSystemMetricsCharts(List<model.SystemMetricsData> filteredSystemMetricsDataList) {
  Map<DateTime, double> data = new Map.fromIterable(filteredSystemMetricsDataList,
      key: (item) => (item as model.SystemMetricsData).datetime.toLocal(),
      value: (item) => (item as model.SystemMetricsData).cpuPercent);
  int maxPercentage = 100;
  view.contentView.cpuPercentSystemMetricsTimeseries.updateChart([data], upperLimit: maxPercentage);

  data = new Map.fromIterable(filteredSystemMetricsDataList,
      key: (item) => (item as model.SystemMetricsData).datetime.toLocal(),
      value: (item) => model.SystemMetricsData.sizeInGB((item as model.SystemMetricsData).diskUsage['used']));
  double maxDiskSpace = model.SystemMetricsData.sizeInGB(filteredSystemMetricsDataList.last.diskUsage['total']);
  view.contentView.diskUsageSystemMetricsTimeseries.updateChart([data], upperLimit: maxDiskSpace);

  data = new Map.fromIterable(filteredSystemMetricsDataList,
      key: (item) => (item as model.SystemMetricsData).datetime.toLocal(),
      value: (item) => model.SystemMetricsData.sizeInGB((item as model.SystemMetricsData).memoryUsage['used']));
  double maxMemory = model.SystemMetricsData.sizeInGB(filteredSystemMetricsDataList.last.memoryUsage['available']);
  view.contentView.memoryUsageSystemMetricsTimeseries.updateChart([data], upperLimit: maxMemory);
}

DateTime getEndDateTimeForPeriod() {
  var now = DateTime.now();
  var xUpperLimitDateTime = new DateTime(now.year, now.month, now.day + 1, 00);
  return xUpperLimitDateTime;
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
