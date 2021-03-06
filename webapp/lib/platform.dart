import 'dart:async';

import 'package:firebase/firebase.dart' as firebase;
import 'package:firebase/firestore.dart' as firestore;
import 'package:nook_watcher/model.dart';

import 'controller.dart' as controller;
import 'logger.dart';
import 'platform_constants.dart' as platform_constants;

Logger log = new Logger('platform.dart');

firestore.Firestore _firestoreInstance;

init() async {
  await platform_constants.init();

  firebase.initializeApp(
    apiKey: platform_constants.apiKey,
    authDomain: platform_constants.authDomain,
    databaseURL: platform_constants.databaseURL,
    projectId: platform_constants.projectId,
    storageBucket: platform_constants.storageBucket,
    messagingSenderId: platform_constants.messagingSenderId);

  // Firebase login
  firebaseAuth.onAuthStateChanged.listen((firebase.User user) async {
    if (user == null) { // User signed out
      controller.command(controller.UIAction.userSignedOut, null);
      return;
    }
    // User signed in
    String photoURL = firebaseAuth.currentUser.photoURL;
    if (photoURL == null) {
      photoURL =  '/assets/user_image_placeholder.png';
    }
    _firestoreInstance = firebase.firestore();
    controller.command(controller.UIAction.userSignedIn, new controller.UserData(user.displayName, user.email, photoURL));
  });
}

firebase.Auth get firebaseAuth => firebase.auth();

/// Signs the user in.
signIn() {
  var provider = new firebase.GoogleAuthProvider();
  firebaseAuth.signInWithPopup(provider);
}

/// Signs the user out.
signOut() {
  firebaseAuth.signOut();
}

/// Returns true if a user is signed-in.
bool isUserSignedIn() {
  return firebaseAuth.currentUser != null;
}

typedef CollectionListener(List<DocSnapshot> changes);

Future<List<String>> get activeProjects async =>
    (await _firestoreInstance.collection('projects').where('archived', '==', false).get()).docs.map((doc) => doc.id).toList();

Future<Map<String, List<String>>> get projectsDrivers async {
  Map<String, List<String>> projectsDrivers = {};
  for (var project in (await activeProjects)) {
    projectsDrivers[project] = (await _firestoreInstance.collection('projects/$project/driver_metrics')
      .where('archived', '==', false).get())
        .docs.map((doc) => doc.id).toList();
  }
  return projectsDrivers;
}

StreamSubscription listenForMetrics(String collectionRoot, DateTime periodFilterDatetime, String fieldPath, CollectionListener listener) {
  log.verbose('Loading from metrics ${collectionRoot}');
  var query;
  if (periodFilterDatetime != null) {
    query = _firestoreInstance
      .collection(collectionRoot)
      .where(fieldPath, '>', periodFilterDatetime.toUtc().toIso8601String());
  } else {
    query = _firestoreInstance.collection(collectionRoot);
  }
  return query.onSnapshot.listen((snapshots) {
    List<DocSnapshot> changes = [];
    log.verbose("Starting processing ${snapshots.docChanges().length} changes.");
    for (var docChange in snapshots.docChanges()) {
      log.verbose('Processing ${docChange.doc.id}');
      changes.add(new DocSnapshot(docChange.doc.id, docChange.doc.data()));
    }
    listener(changes);
  });
}
