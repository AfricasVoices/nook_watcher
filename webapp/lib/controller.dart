library controller;

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
  systemEventsDataUpdated
}

class Data {}

class UserData extends Data {
  String displayName;
  String email;
  String photoUrl;
  UserData(this.displayName, this.email, this.photoUrl);
}

List<model.NeedsReplyData> needsReplyDataList;
List<model.SystemEventsData> systemEventsDataList;

model.User signedInUser;

void init() async {
  view.init();
  await platform.init();
}

void initUI() {
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
      needsReplyDataList.removeWhere((d) => updatedIds.contains(d.docId));
      needsReplyDataList.addAll(updatedData);
      command(UIAction.needsReplyDataUpdated, null);
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

void command(UIAction action, Data data) {
  switch (action) {
    /*** User */
    case UIAction.userSignedOut:
      signedInUser = null;
      view.authHeaderView.signOut();
      view.initSignedOutView();
      break;
    case UIAction.userSignedIn:
      UserData userData = data;
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
      Map<DateTime, int> data = new Map.fromIterable(needsReplyDataList,
        key: (item) => (item as model.NeedsReplyData).datetime,
        value: (item) => (item as model.NeedsReplyData).needsReplyCount);
      view.contentView.needsReplyTimeseries.updateChart([data]);

      data = new Map.fromIterable(needsReplyDataList,
        key: (item) => (item as model.NeedsReplyData).datetime,
        value: (item) => (item as model.NeedsReplyData).needsReplyAndEscalateCount);
      view.contentView.needsReplyAndEscalateTimeseries.updateChart([data]);


      data = new Map.fromIterable(needsReplyDataList,
        key: (item) => (item as model.NeedsReplyData).datetime,
        value: (item) => (item as model.NeedsReplyData).needsReplyMoreThan24h);
      view.contentView.needsReplyMoreThan24hTimeseries.updateChart([data]);


      data = new Map.fromIterable(needsReplyDataList,
        key: (item) => (item as model.NeedsReplyData).datetime,
        value: (item) => (item as model.NeedsReplyData).needsReplyAndEscalateMoreThan24hCount);
      view.contentView.needsReplyAndEscalateMoreThan24hTimeseries.updateChart([data]);


      DateTime latestDateTime = data.keys.reduce((dt1, dt2) => dt1.isAfter(dt2) ? dt1 : dt2);
      var latestData = needsReplyDataList.firstWhere((d) => d.datetime == latestDateTime, orElse: () => null);

      view.contentView.needsReplyLatestValue.updateChart('${latestData.needsReplyCount}');
      view.contentView.needsReplyAndEscalateLatestValue.updateChart('${latestData.needsReplyAndEscalateCount}');
      view.contentView.needsReplyMoreThan24hLatestValue.updateChart('${latestData.needsReplyMoreThan24h}');
      view.contentView.needsReplyAndEscalateMoreThan24hLatestValue.updateChart('${latestData.needsReplyAndEscalateMoreThan24hCount}');

      view.contentView.needsReplyAgeHistogram.updateChart(latestData.needsReplyMessagesByDate);
      break;

    case UIAction.systemEventsDataUpdated:
      Map<DateTime, int> data = new Map.fromIterable(systemEventsDataList,
          key: (item) => (item as model.SystemEventsData).timestamp,
          value: (item) => 1);
      view.contentView.restartSystemEventTimeseries.updateChart([data]);
      break;
  }
}
