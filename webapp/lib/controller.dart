library controller;

import 'dart:convert' show json;

import 'logger.dart';
import 'model.dart' as model;
import 'platform.dart' as platform;
import 'view.dart' as view;

Logger log = new Logger('controller.dart');

final METRICS_ROOT_COLLECTION_KEY = 'daily_tag_metrics';

enum UIActionObject {
  conversation,
  message,
}

enum UIAction {
  userSignedIn,
  userSignedOut,
  signInButtonClicked,
  signOutButtonClicked
}

class Data {}

class UserData extends Data {
  String displayName;
  String email;
  String photoUrl;
  UserData(this.displayName, this.email, this.photoUrl);
}

List<model.MetricsSnapshot> metrics;
model.User signedInUser;

void init() async {
  view.init();
  await platform.init();
}

void initUI() {
  metrics = [];

  platform.listenForMetrics(
    METRICS_ROOT_COLLECTION_KEY,
    (updatedMetrics) {
      if (signedInUser == null) {
        log.error("Receiving metrics when user is not logged it, something's wrong, abort.");
        return;
      }
      var updatedIds = updatedMetrics.map((m) => m.keys.first).toSet();
      metrics.removeWhere((m) => updatedIds.contains(m.docId));
      var newMetrics = updatedMetrics.map((m) => model.MetricsSnapshot.fromData(m));
      metrics.addAll(newMetrics);
      view.contentView.show(metrics.toString());
    }
  );
}

void command(UIAction action, Data data) {
  switch (action) {
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
  }
}
