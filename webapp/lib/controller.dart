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
  chartsFiltered
}

enum ChartPeriodFilters {
  alltime,
  days1,
  days8,
  days15,
  month1,
}

class Data {}

class ChartFilterdata extends Data {
  ChartPeriodFilters periodFilter;
}

class UserData extends Data {
  String displayName;
  String email;
  String photoUrl;
  UserData(this.displayName, this.email, this.photoUrl);
}


Map<String, Set> projectList;
List<model.NeedsReplyData> needsReplyDataList;
List<model.SystemEventsData> systemEventsDataList;
List<model.SystemMetricsData> systemMetricsDataList;
List<model.DirectorySizeMetricsData> dirSizeMetricsDataList;

model.User signedInUser;

Map<String, Timer> projectTimers = {};

void init() async {
  view.init();
  await platform.init();
}

void initUI() {
  projectList = {};
  needsReplyDataList = [];
  systemEventsDataList = [];
  systemMetricsDataList = [];
  dirSizeMetricsDataList = [];

  platform.listenForMetrics(
    NEEDS_REPLY_METRICS_ROOT_COLLECTION_KEY,
    (List<model.DocSnapshot> updatedMetrics) {
      if (signedInUser == null) {
        log.error("Receiving metrics when user is not logged it, something's wrong, abort.");
        return;
      }
      var updatedIds = updatedMetrics.map((m) => m.id).toSet();
      var updatedData = updatedMetrics.map((doc) => model.NeedsReplyData.fromSnapshot(doc)).toList();
      projectList[NEEDS_REPLY_METRICS_ROOT_COLLECTION_KEY] = updatedData.map((m) => m.project).toSet();
      needsReplyDataList.removeWhere((d) => updatedIds.contains(d.docId));
      needsReplyDataList.addAll(updatedData);
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
      projectList[SYSTEM_EVENTS_ROOT_COLLECTION_KEY] = updatedData.map((m) => m.project).toSet();
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

  for (var project in projectList[NEEDS_REPLY_METRICS_ROOT_COLLECTION_KEY]) {
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
      if (projectData.project == view.contentView.projectSelectorView.selectedProject) {
        view.contentView.stale = true;
      }
    });
    projectTimers[projectData.project] = timer;
  }
}

void checkNeedsReplyMetricsStale(List<model.NeedsReplyData> updatedData) {
  updatedData.sort((d1, d2) => d1.datetime.compareTo(d2.datetime));

  var selectedProjectName = view.contentView.projectSelectorView.selectedProject;
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
    case UIAction.projectSelected:
      view.contentView.populateUrlFilters();

      var selectedProjectTimer = projectTimers[view.contentView.projectSelectorView.selectedProject];
      if (selectedProjectTimer != null && selectedProjectTimer.isActive) {
        view.contentView.stale = false;
      } else {
        view.contentView.stale = true;
      }
      break;
    case UIAction.needsReplyDataUpdated:
      view.contentView.projectSelectorView.populateProjects(projectList);

      List<model.NeedsReplyData> selectedProjectNeedsReplyDataList = [];
      selectedProjectNeedsReplyDataList = needsReplyDataList.where((d) =>
          d.project == view.contentView.projectSelectorView.selectedProject).toList();
      updateNeedsReplyCharts(selectedProjectNeedsReplyDataList);
      view.contentView.changeViewOnUrlChange();
      break;

    case UIAction.systemEventsDataUpdated:
    view.contentView.projectSelectorView.populateProjects(projectList);
      updateSystemEventsCharts(systemEventsDataList);
      view.contentView.changeViewOnUrlChange();
      break;
    
    case UIAction.systemMetricsDataUpdated:
      updateSystemMetricsCharts(systemMetricsDataList);
      view.contentView.changeViewOnUrlChange();
      break;
    
    case UIAction.dirSizeMetricsDataUpdated:
      view.contentView.changeViewOnUrlChange();
      break;

    case UIAction.chartsFiltered:
      view.contentView.populateUrlFilters();

      List<model.NeedsReplyData> selectedProjectNeedsReplyDataList = [];
      List<model.SystemMetricsData> filteredSystemMetricsDataList = [];
      List<model.SystemEventsData> filteredSystemEventsDataList = [];

      DateTime filterDate = getFilteredDate(actionData);

      if (filterDate != null) {
        selectedProjectNeedsReplyDataList = needsReplyDataList.where((d) =>
            d.project == view.contentView.projectSelectorView.selectedProject &&
            d.datetime.isAfter(filterDate)).toList();
        filteredSystemMetricsDataList = systemMetricsDataList.where((d) => d.datetime.isAfter(filterDate)).toList();
        filteredSystemEventsDataList = systemEventsDataList.where((d) => d.timestamp.isAfter(filterDate)).toList();
      } else {
        selectedProjectNeedsReplyDataList = needsReplyDataList.where((d) =>
            d.project == view.contentView.projectSelectorView.selectedProject).toList();
        filteredSystemMetricsDataList = systemMetricsDataList;
        filteredSystemEventsDataList = systemEventsDataList;
      }
      updateNeedsReplyCharts(selectedProjectNeedsReplyDataList);
      updateSystemMetricsCharts(filteredSystemMetricsDataList);
      updateSystemEventsCharts(filteredSystemEventsDataList);
    break;
  }
}

void updateNeedsReplyCharts(List<model.NeedsReplyData> selectedProjectNeedsReplyDataList) {
  if (selectedProjectNeedsReplyDataList.isEmpty) return;

  var timeScaleUnit = view.ChartFiltersView().selectedPeriodFilter == 'ChartPeriodFilters.days1' ? 'hour' : 'day';

  Map<DateTime, int> data = new Map.fromIterable(selectedProjectNeedsReplyDataList,
    key: (item) => (item as model.NeedsReplyData).datetime.toLocal(),
    value: (item) => (item as model.NeedsReplyData).needsReplyCount);
  view.contentView.needsReplyTimeseries.updateChart([data], timeScaleUnit);

  data = new Map.fromIterable(selectedProjectNeedsReplyDataList,
    key: (item) => (item as model.NeedsReplyData).datetime.toLocal(),
    value: (item) => (item as model.NeedsReplyData).needsReplyAndEscalateCount);
  view.contentView.needsReplyAndEscalateTimeseries.updateChart([data], timeScaleUnit);

  data = new Map.fromIterable(selectedProjectNeedsReplyDataList,
    key: (item) => (item as model.NeedsReplyData).datetime.toLocal(),
    value: (item) => (item as model.NeedsReplyData).needsReplyMoreThan24h);
  view.contentView.needsReplyMoreThan24hTimeseries.updateChart([data], timeScaleUnit);

  data = new Map.fromIterable(selectedProjectNeedsReplyDataList,
    key: (item) => (item as model.NeedsReplyData).datetime.toLocal(),
    value: (item) => (item as model.NeedsReplyData).needsReplyAndEscalateMoreThan24hCount);
  view.contentView.needsReplyAndEscalateMoreThan24hTimeseries.updateChart([data], timeScaleUnit);

  DateTime latestDateTime = data.keys.reduce((dt1, dt2) => dt1.isAfter(dt2) ? dt1 : dt2);
  var latestData = selectedProjectNeedsReplyDataList.firstWhere((d) => d.datetime.toLocal() == latestDateTime, orElse: () => null);

  view.contentView.needsReplyLatestValue.updateChart('${latestData.needsReplyCount}');
  view.contentView.needsReplyAndEscalateLatestValue.updateChart('${latestData.needsReplyAndEscalateCount}');
  view.contentView.needsReplyMoreThan24hLatestValue.updateChart('${latestData.needsReplyMoreThan24h}');
  view.contentView.needsReplyAndEscalateMoreThan24hLatestValue.updateChart('${latestData.needsReplyAndEscalateMoreThan24hCount}');

  view.contentView.needsReplyAgeHistogram.updateChart(latestData.needsReplyMessagesByDate);
}

void updateSystemEventsCharts(List<model.SystemEventsData> filteredSystemEventsDataList) {
  if (filteredSystemEventsDataList.isEmpty) return;
  
  var rapidProEventData = filteredSystemEventsDataList.where((eventData) =>
      (eventData.systemName == 'rapidpro_adapter' || eventData.systemName == 'rapidpro_adapter.sh') &&
      eventData.project == view.contentView.projectSelectorView.selectedProject);
  var pubsubEventData = filteredSystemEventsDataList.where((eventData) =>
      (eventData.systemName == 'pubsub_handler' || eventData.systemName == 'pubsub_handler.sh') &&
      eventData.project == view.contentView.projectSelectorView.selectedProject);

  Map<DateTime, int> data = new Map.fromIterable(rapidProEventData,
      key: (item) => (item as model.SystemEventsData).timestamp.toLocal(),
      value: (item) => 1);
  view.contentView.rapidProSystemEventTimeseries.updateChart([data]);

  data = new Map.fromIterable(pubsubEventData,
      key: (item) => (item as model.SystemEventsData).timestamp.toLocal(),
      value: (item) => 1);
  view.contentView.pubsubSystemEventTimeseries.updateChart([data]);
}

void updateSystemMetricsCharts(List<model.SystemMetricsData> filteredSystemMetricsDataList) {
  Map<DateTime, double> data = new Map.fromIterable(filteredSystemMetricsDataList,
      key: (item) => (item as model.SystemMetricsData).datetime.toLocal(),
      value: (item) => (item as model.SystemMetricsData).cpuPercent);
  view.contentView.cpuPercentSystemMetricsTimeseries.updateChart([data]);

  data = new Map.fromIterable(filteredSystemMetricsDataList,
      key: (item) => (item as model.SystemMetricsData).datetime.toLocal(),
      value: (item) => model.SystemMetricsData.sizeInGB((item as model.SystemMetricsData).diskUsage['used']));
  view.contentView.diskUsageSystemMetricsTimeseries.updateChart([data]);

  data = new Map.fromIterable(filteredSystemMetricsDataList,
      key: (item) => (item as model.SystemMetricsData).datetime.toLocal(),
      value: (item) => model.SystemMetricsData.sizeInGB((item as model.SystemMetricsData).memoryUsage['used']));
  view.contentView.memoryUsageSystemMetricsTimeseries.updateChart([data]);
}

DateTime getFilteredDate(ChartFilterdata filterData) {
  DateTime now = new DateTime.now();
  DateTime filterDate;

  switch (filterData.periodFilter) {
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
