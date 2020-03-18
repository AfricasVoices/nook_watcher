import 'dart:async';
import 'dart:html';

import 'logger.dart';
import 'controller.dart' as controller;

Logger log = new Logger('view.dart');

Element get headerElement => querySelector('header');
Element get mainElement => querySelector('main');
Element get footerElement => querySelector('footer');

AuthMainView authMainView;
AuthHeaderView authHeaderView;
BannerView bannerView;
ContentView contentView;
SnackbarView snackbarView;
StatusView statusView;

void init() {
  authMainView = new AuthMainView();
  authHeaderView = new AuthHeaderView();
  bannerView = new BannerView();
  contentView = new ContentView();
  snackbarView = new SnackbarView();
  statusView = new StatusView();

  headerElement.insertAdjacentElement('beforeBegin', bannerView.bannerElement);
  headerElement.append(authHeaderView.authElement);
}

void initSignedInView() {
  clearMain();
  mainElement
    ..append(contentView.contentElement)
    ..append(snackbarView.snackbarElement);
  statusView.showNormalStatus('signed in');
}

void initSignedOutView() {
  clearMain();
  mainElement
    ..append(authMainView.authElement);
  statusView.showNormalStatus('signed out');
}

void clearMain() {
  authMainView.authElement.remove();
  contentView.contentElement.remove();
  snackbarView.snackbarElement.remove();
}


class AuthHeaderView {
  DivElement authElement;
  DivElement _userPic;
  DivElement _userName;
  ButtonElement _signOutButton;
  ButtonElement _signInButton;

  AuthHeaderView() {
    authElement = new DivElement()
      ..classes.add('auth');

    _userPic = new DivElement()
      ..classes.add('user-pic');
    authElement.append(_userPic);

    _userName = new DivElement()
      ..classes.add('user-name');
    authElement.append(_userName);

    _signOutButton = new ButtonElement()
      ..text = 'Sign out'
      ..onClick.listen((_) => controller.command(controller.UIAction.signOutButtonClicked, null));
    authElement.append(_signOutButton);

    _signInButton = new ButtonElement()
      ..text = 'Sign in'
      ..onClick.listen((_) => controller.command(controller.UIAction.signInButtonClicked, null));
    authElement.append(_signInButton);
  }

  void signIn(String userName, userPicUrl) {
    // Set the user's profile pic and name
    _userPic.style.backgroundImage = 'url($userPicUrl)';
    _userName.text = userName;

    // Show user's profile pic, name and sign-out button.
    _userName.attributes.remove('hidden');
    _userPic.attributes.remove('hidden');
    _signOutButton.attributes.remove('hidden');

    // Hide sign-in button.
    _signInButton.setAttribute('hidden', 'true');
  }

  void signOut() {
    // Hide user's profile pic, name and sign-out button.
    _userName.attributes['hidden'] = 'true';
    _userPic.attributes['hidden'] = 'true';
    _signOutButton.attributes['hidden'] = 'true';

    // Show sign-in button.
    _signInButton.attributes.remove('hidden');
  }
}

class AuthMainView {
  DivElement authElement;
  ButtonElement _signInButton;

  final descriptionText1 = 'Sign in to Nook Watcher where you can monitor Nook deployments.';
  final descriptionText2 = 'Please contact Africa\'s Voices for login details.';

  AuthMainView() {
    authElement = new DivElement()
      ..classes.add('auth-main');

    var logosContainer = new DivElement()
      ..classes.add('auth-main__logos');
    authElement.append(logosContainer);

    var avfLogo = new ImageElement(src: 'assets/africas-voices-logo.svg')
      ..classes.add('partner-logo')
      ..classes.add('partner-logo--avf');
    logosContainer.append(avfLogo);

    var shortDescription = new DivElement()
      ..classes.add('project-description')
      ..append(new ParagraphElement()..text = descriptionText1)
      ..append(new ParagraphElement()..text = descriptionText2);
    authElement.append(shortDescription);

    _signInButton = new ButtonElement()
      ..text = 'Sign in'
      ..onClick.listen((_) => controller.command(controller.UIAction.signInButtonClicked, null));
    authElement.append(_signInButton);
  }
}

class BannerView {
  DivElement bannerElement;
  DivElement _contents;

  /// The length of the animation in milliseconds.
  /// This must match the animation length set in banner.css
  static const ANIMATION_LENGTH_MS = 200;

  BannerView() {
    bannerElement = new DivElement()
      ..id = 'banner'
      ..classes.add('hidden');

    _contents = new DivElement()
      ..classes.add('contents');
    bannerElement.append(_contents);
  }

  void showBanner(String message) {
    _contents.text = message;
    bannerElement.classes.remove('hidden');
  }

  void hideBanner() {
    bannerElement.classes.add('hidden');
    // Remove the contents after the animation ends
    new Timer(new Duration(milliseconds: ANIMATION_LENGTH_MS), () => _contents.text = '');
  }
}

class ContentView {
  DivElement contentElement;

  ContentView() {
    contentElement = new DivElement();
  }

  void show(String content) {
    contentElement.text = content;
  }
}

enum SnackbarNotificationType {
  info,
  success,
  warning,
  error
}

class SnackbarView {
  DivElement snackbarElement;
  DivElement _contents;

  /// How many seconds the snackbar will be displayed on screen before disappearing.
  static const SECONDS_ON_SCREEN = 3;

  /// The length of the animation in milliseconds.
  /// This must match the animation length set in snackbar.css
  static const ANIMATION_LENGTH_MS = 200;

  SnackbarView() {
    snackbarElement = new DivElement()
      ..id = 'snackbar'
      ..classes.add('hidden')
      ..title = 'Click to close notification.'
      ..onClick.listen((_) => hideSnackbar());

    _contents = new DivElement()
      ..classes.add('contents');
    snackbarElement.append(_contents);
  }

  void showSnackbar(String message, SnackbarNotificationType type) {
    _contents.text = message;
    snackbarElement.classes.remove('hidden');
    snackbarElement.setAttribute('type', type.toString().replaceAll('SnackbarNotificationType.', ''));
    new Timer(new Duration(seconds: SECONDS_ON_SCREEN), () => hideSnackbar());
  }

  void hideSnackbar() {
    snackbarElement.classes.toggle('hidden', true);
    snackbarElement.attributes.remove('type');
    // Remove the contents after the animation ends
    new Timer(new Duration(milliseconds: ANIMATION_LENGTH_MS), () => _contents.text = '');
  }
}

class StatusView {
  DivElement statusElement;

  StatusView() {
    statusElement = new DivElement()
      ..classes.add('status');
  }

  void showNormalStatus(String text) {
    statusElement.text = text;
    statusElement.classes.toggle('status--warning', false);
  }

  void showWarningStatus(String text) {
    statusElement.text = text;
    statusElement.classes.toggle('status--warning', true);
  }
}
