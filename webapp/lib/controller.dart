library controller;

import 'dart:async';

import 'logger.dart';
import 'model.dart' as model;
import 'platform.dart' as platform;
import 'view.dart' as view;

Logger log = new Logger('controller.dart');

final NEEDS_REPLY_METRICS_ROOT_COLLECTION_KEY = 'needs_reply_metrics';
final SYSTEM_EVENTS_ROOT_COLLECTION_KEY = 'system_events';

enum UIAction {
  userSignedIn,
  userSignedOut,
  signInButtonClicked,
  signOutButtonClicked,
  needsReplyDataUpdated,
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

Set<String> projectList;
List<model.NeedsReplyData> needsReplyDataList;
List<model.SystemEventsData> systemEventsDataList;

model.User signedInUser;

void init() async {
  view.init();
  await platform.init();
}

void initUI() {
  projectList = {};
  needsReplyDataList = [];
  systemEventsDataList = [];

  platform.listenForMetrics(
    NEEDS_REPLY_METRICS_ROOT_COLLECTION_KEY,
    (List<model.DocSnapshot> updatedMetrics) {
      if (signedInUser == null) {
        log.error("Receiving metrics when user is not logged it, something's wrong, abort.");
        return;
      }
      var updatedIds = updatedMetrics.map((m) => m.id).toSet();
      var updatedData = updatedMetrics.map((doc) => model.NeedsReplyData.fromSnapshot(doc)).toList();
      projectList.addAll(updatedData.map((m) => m.project).toSet());
      needsReplyDataList.removeWhere((d) => updatedIds.contains(d.docId));
      needsReplyDataList.addAll(updatedData);
      command(UIAction.needsReplyDataUpdated, null);
      Timer.periodic(Duration(seconds: 5), (_) => checkNeedsReplyMetricsPipelineDataFlow());
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
}

void checkNeedsReplyMetricsPipelineDataFlow() {
  var now = new DateTime.now();
  var sortedNeedsReplyDataList = List.from(needsReplyDataList);
  sortedNeedsReplyDataList.sort((d1, d2) => d1.datetime.compareTo(d2.datetime));
  
  var lastNeedsReplyEntry = sortedNeedsReplyDataList.where((entry)=>
      entry.project == view.contentView.projectSelectorView.selectedProject).last;

  var lastUpdateTimeDiff =  now.difference(lastNeedsReplyEntry.datetime).inHours;
  print(lastUpdateTimeDiff);
  if (lastUpdateTimeDiff > 1) {
    view.contentView.conversationsCharts.forEach((chart) => chart.classes.add('stale'));
  } else {
    view.contentView.conversationsCharts.forEach((chart) => chart.classes.remove('stale'));
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
      checkNeedsReplyMetricsPipelineDataFlow();
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
      updateSystemEventsCharts(systemEventsDataList);
      view.contentView.changeViewOnUrlChange();
      break;
    
    case UIAction.chartsFiltered:
      view.contentView.populateUrlFilters();

      List<model.NeedsReplyData> selectedProjectNeedsReplyDataList = [];
      List<model.SystemEventsData> filteredSystemEventsDataList = [];

      DateTime filterDate = getFilteredDate(actionData);

      if (filterDate != null) {
        selectedProjectNeedsReplyDataList = needsReplyDataList.where((d) => 
            d.project == view.contentView.projectSelectorView.selectedProject &&
            d.datetime.isAfter(filterDate)).toList();
        filteredSystemEventsDataList = systemEventsDataList.where((d) => d.timestamp.isAfter(filterDate)).toList();
      } else {
        selectedProjectNeedsReplyDataList = needsReplyDataList.where((d) => 
            d.project == view.contentView.projectSelectorView.selectedProject).toList();
        filteredSystemEventsDataList = systemEventsDataList;
      }
      updateNeedsReplyCharts(selectedProjectNeedsReplyDataList);
      updateSystemEventsCharts(filteredSystemEventsDataList);
    break;
  }
}

void updateNeedsReplyCharts(List<model.NeedsReplyData> selectedProjectNeedsReplyDataList) {
  Map<DateTime, int> data = new Map.fromIterable(selectedProjectNeedsReplyDataList,
    key: (item) => (item as model.NeedsReplyData).datetime,
    value: (item) => (item as model.NeedsReplyData).needsReplyCount);
  view.contentView.needsReplyTimeseries.updateChart([data]);

  data = new Map.fromIterable(selectedProjectNeedsReplyDataList,
    key: (item) => (item as model.NeedsReplyData).datetime,
    value: (item) => (item as model.NeedsReplyData).needsReplyAndEscalateCount);
  view.contentView.needsReplyAndEscalateTimeseries.updateChart([data]);

  data = new Map.fromIterable(selectedProjectNeedsReplyDataList,
    key: (item) => (item as model.NeedsReplyData).datetime,
    value: (item) => (item as model.NeedsReplyData).needsReplyMoreThan24h);
  view.contentView.needsReplyMoreThan24hTimeseries.updateChart([data]);

  data = new Map.fromIterable(selectedProjectNeedsReplyDataList,
    key: (item) => (item as model.NeedsReplyData).datetime,
    value: (item) => (item as model.NeedsReplyData).needsReplyAndEscalateMoreThan24hCount);
  view.contentView.needsReplyAndEscalateMoreThan24hTimeseries.updateChart([data]);

  DateTime latestDateTime = data.keys.reduce((dt1, dt2) => dt1.isAfter(dt2) ? dt1 : dt2);
  var latestData = selectedProjectNeedsReplyDataList.firstWhere((d) => d.datetime == latestDateTime, orElse: () => null);

  view.contentView.needsReplyLatestValue.updateChart('${latestData.needsReplyCount}');
  view.contentView.needsReplyAndEscalateLatestValue.updateChart('${latestData.needsReplyAndEscalateCount}');
  view.contentView.needsReplyMoreThan24hLatestValue.updateChart('${latestData.needsReplyMoreThan24h}');
  view.contentView.needsReplyAndEscalateMoreThan24hLatestValue.updateChart('${latestData.needsReplyAndEscalateMoreThan24hCount}');

  view.contentView.needsReplyAgeHistogram.updateChart(latestData.needsReplyMessagesByDate);
}

void updateSystemEventsCharts(List<model.SystemEventsData> filteredSystemEventsDataList) {
  var rapidProEventData = filteredSystemEventsDataList.where((eventData) =>
      eventData.systemName == 'rapidpro_adapter' &&
      eventData.project == view.contentView.projectSelectorView.selectedProject);
  var pubsubEventData = filteredSystemEventsDataList.where((eventData) =>
      eventData.systemName == 'pubsub_handler' &&
      eventData.project == view.contentView.projectSelectorView.selectedProject);
  
  Map<DateTime, int> data = new Map.fromIterable(rapidProEventData,
      key: (item) => (item as model.SystemEventsData).timestamp,
      value: (item) => 1);
  view.contentView.rapidProSystemEventTimeseries.updateChart([data]);

  data = new Map.fromIterable(pubsubEventData,
      key: (item) => (item as model.SystemEventsData).timestamp,
      value: (item) => 1);
  view.contentView.pubsubSystemEventTimeseries.updateChart([data]);
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
