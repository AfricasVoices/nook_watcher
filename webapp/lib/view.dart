import 'dart:async';
import 'dart:html';

import 'logger.dart';
import 'controller.dart' as controller;
import 'charts.dart' as charts;
import 'model.dart' as model;

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
  contentView.tabElement.classes.remove('hidden');
  contentView.projectSelectorView.projectSelector.classes.remove('hidden');
  ChartFiltersView().chartFiltersContainer.classes.remove('hidden');
  mainElement
    ..append(contentView.contentElement)
    ..append(snackbarView.snackbarElement);
  statusView.showNormalStatus('signed in');
}

void initSignedOutView() {
  clearMain();
  contentView.tabElement.classes.add('hidden');
  contentView.projectSelectorView.projectSelector.classes.add('hidden');
  ChartFiltersView().chartFiltersContainer.classes.add('hidden');
  mainElement
    ..append(authMainView.authElement);
  statusView.showNormalStatus('signed out');
}

void clearMain() {
  authMainView.authElement.remove();
  contentView.contentElement.remove();
  snackbarView.snackbarElement.remove();
}

class UrlView {
  static Map<String, String> getPageUrlFilters() {
    Map<String, String> pageFiltersMap = {};
    var uri = Uri.parse(window.location.href);
    pageFiltersMap.addAll(uri.queryParameters);
    return pageFiltersMap;
  }

  static setPageUrlFilters(Map<String, String> pageFiltersMap) {
    var currentPageFilters = getPageUrlFilters();
    currentPageFilters.addAll(pageFiltersMap);
    var uri = Uri.parse(window.location.href);
    uri = uri.replace(queryParameters: currentPageFilters);
    window.history.pushState('', '', uri.toString());
  }
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

class ProjectSelectorView {
  DivElement projectSelector;
  SelectElement _projectOptions;

  ProjectSelectorView() {
    projectSelector = new DivElement()
      ..id = 'project-selector';
    _projectOptions = new SelectElement();
    _projectOptions.onChange.listen((_) {
      controller.command(controller.UIAction.projectSelected, new controller.ProjectData(_projectOptions.value));
    });
    projectSelector.append(_projectOptions);
  }

  String get selectedProject => _projectOptions.value;

  void set selectedProject (String projectName) => _projectOptions.value = projectName;

  set projectOptions(List<String> options) {
    _projectOptions.children.clear();
    for (var option in options) {
      var optionElement = new OptionElement()
        ..text = option
        ..value = option;
      _projectOptions.add(optionElement, null);
    }
  }
}

class ChartFiltersView {
  static final ChartFiltersView _singleton = new ChartFiltersView._internal();

  factory ChartFiltersView() {
    return _singleton;
  }

  DivElement chartFiltersContainer;
  DivElement _singleFilterSpan;
  LabelElement _periodFilterTitle;
  SelectElement _periodFilter;

  ChartFiltersView._internal() {
    chartFiltersContainer = new DivElement()..classes.add('chart-filters');
    _singleFilterSpan = new DivElement()..classes.add('chart-filter');
    _periodFilterTitle = new LabelElement()..text = 'Period:';
    _periodFilter = new SelectElement()..classes.add('period-filter');
    _periodFilter.onChange.listen((_) => controller.command(controller.UIAction.chartsFiltered, new controller.ChartFilterData(selectedPeriodFilter)));
    _singleFilterSpan.append(_periodFilterTitle);
    _singleFilterSpan.append(_periodFilter);
    chartFiltersContainer.append(_singleFilterSpan);
  }

  controller.ChartPeriodFilters get selectedPeriodFilter =>
      controller.ChartPeriodFilters.values.singleWhere((v) => v.toString() == _periodFilter.value);

  void set selectedPeriodFilter (controller.ChartPeriodFilters periodFilter) =>
      _periodFilter.value = periodFilter.toString();

  set periodFilterOptions(List<controller.ChartPeriodFilters> options) {
    _periodFilter.children.clear();
    for (var option in options) {
      var optionElement = new OptionElement()
        ..text = _periodFilterValue(option)
        ..value = option.toString();
      _periodFilter.add(optionElement, null);
    }
  }

  String _periodFilterValue (controller.ChartPeriodFilters filter) {
    String filteredValue;
    switch (filter) {
      case controller.ChartPeriodFilters.alltime:
        filteredValue = 'All Time';
        break;
      case controller.ChartPeriodFilters.days1:
        filteredValue = '1 Day';
      break;
      case controller.ChartPeriodFilters.days8:
        filteredValue = '8 days';
      break;
      case controller.ChartPeriodFilters.days15:
        filteredValue = '15 days';
      break;
      case controller.ChartPeriodFilters.month1:
        filteredValue = '1 month';
      break;
    }
    return filteredValue;
  }
}

class ContentView {
  DivElement tabElement;
  ButtonElement _systemTabLink;
  ButtonElement _conversationTabLink;

  ProjectSelectorView projectSelectorView;

  DivElement contentElement;
  DivElement systemChartsTabContent;
  DivElement conversationChartsTabContent;
  DivElement chartDataLastUpdateTime;

  charts.SingleIndicatorChartView needsReplyLatestValue;
  charts.SingleIndicatorChartView needsReplyAndEscalateLatestValue;
  charts.SingleIndicatorChartView needsReplyMoreThan24hLatestValue;
  charts.SingleIndicatorChartView needsReplyAndEscalateMoreThan24hLatestValue;
  charts.DailyTimeseriesLineChartView needsReplyTimeseries;
  charts.DailyTimeseriesLineChartView needsReplyAndEscalateTimeseries;
  charts.DailyTimeseriesLineChartView needsReplyMoreThan24hTimeseries;
  charts.DailyTimeseriesLineChartView needsReplyAndEscalateMoreThan24hTimeseries;
  charts.DailyTimeseriesLineChartView cpuPercentSystemMetricsTimeseries;
  charts.DailyTimeseriesLineChartView diskUsageSystemMetricsTimeseries;
  charts.DailyTimeseriesLineChartView memoryUsageSystemMetricsTimeseries;
  charts.HistogramChartView needsReplyAgeHistogram;
  List<charts.SystemEventsTimeseriesLineChartView> systemEventsCharts = [];

  ContentView() {
    projectSelectorView = new ProjectSelectorView();
    headerElement.insertAdjacentElement('afterBegin', projectSelectorView.projectSelector);
    headerElement.insertAdjacentElement('afterBegin', ChartFiltersView().chartFiltersContainer); // Initialize Chart Filters

    tabElement = new DivElement()
      ..classes.addAll(['tabs', 'hidden']);
    _conversationTabLink = new ButtonElement()
      ..text = "Conversations"
      ..onClick.listen((_) => controller.command(controller.UIAction.tabSwitched, new controller.ChartTypeData(controller.ChartType.conversation)));
    tabElement.append(_conversationTabLink);

    _systemTabLink = new ButtonElement()
      ..text = "Systems"
      ..onClick.listen((_) => controller.command(controller.UIAction.tabSwitched, new controller.ChartTypeData(controller.ChartType.system)));
    tabElement.append(_systemTabLink);
    headerElement.insertAdjacentElement('afterBegin', tabElement);

    contentElement = new DivElement()
      ..classes.add('charts');

    conversationChartsTabContent = new DivElement()
      ..id = "conversations";

    var singleIndicators = new DivElement()
      ..classes.add('single-indicator-container');
    conversationChartsTabContent.append(singleIndicators);

    needsReplyLatestValue = new charts.SingleIndicatorChartView()
      ..createEmptyChart(titleText: 'needs reply');
    singleIndicators.append(needsReplyLatestValue.chartContainer);

    needsReplyAndEscalateLatestValue = new charts.SingleIndicatorChartView()
      ..createEmptyChart(titleText: 'needs reply and escalate');
    singleIndicators.append(needsReplyAndEscalateLatestValue.chartContainer);

    needsReplyMoreThan24hLatestValue = new charts.SingleIndicatorChartView()
      ..createEmptyChart(titleText: 'needs reply more than 24h');
    singleIndicators.append(needsReplyMoreThan24hLatestValue.chartContainer);

    needsReplyAndEscalateMoreThan24hLatestValue = new charts.SingleIndicatorChartView()
      ..createEmptyChart(titleText: 'needs reply and escalate more than 24h');
    singleIndicators.append(needsReplyAndEscalateMoreThan24hLatestValue.chartContainer);

    chartDataLastUpdateTime = new DivElement()
      ..id = 'charts-last-update';
    conversationChartsTabContent.append(chartDataLastUpdateTime);

    needsReplyTimeseries = new charts.DailyTimeseriesLineChartView();
    conversationChartsTabContent.append(needsReplyTimeseries.chartContainer);
    needsReplyTimeseries.createEmptyChart(
      titleText: 'needs reply',
      datasetLabels: ['needs reply']);

    needsReplyAndEscalateTimeseries = new charts.DailyTimeseriesLineChartView();
    conversationChartsTabContent.append(needsReplyAndEscalateTimeseries.chartContainer);
    needsReplyAndEscalateTimeseries.createEmptyChart(
      titleText: 'needs reply and escalate',
      datasetLabels: ['needs reply and escalate']);

    needsReplyMoreThan24hTimeseries = new charts.DailyTimeseriesLineChartView();
    conversationChartsTabContent.append(needsReplyMoreThan24hTimeseries.chartContainer);
    needsReplyMoreThan24hTimeseries.createEmptyChart(
      titleText: 'needs reply more than 24h',
      datasetLabels: ['needs reply more than 24h']);

    needsReplyAndEscalateMoreThan24hTimeseries = new charts.DailyTimeseriesLineChartView();
    conversationChartsTabContent.append(needsReplyAndEscalateMoreThan24hTimeseries.chartContainer);
    needsReplyAndEscalateMoreThan24hTimeseries.createEmptyChart(
      titleText: 'needs reply and escalate more than 24h',
      datasetLabels: ['needs reply and escalate more than 24h']);

    needsReplyAgeHistogram = new charts.HistogramChartView();
    conversationChartsTabContent.append(needsReplyAgeHistogram.chartContainer);
    needsReplyAgeHistogram.createEmptyChart(
      titleText: 'needs reply messages by date',
      datasetLabel: 'needs reply messages by date');

    systemChartsTabContent = new DivElement()
      ..id = "systems";

    cpuPercentSystemMetricsTimeseries = new charts.DailyTimeseriesLineChartView();
    systemChartsTabContent.append(cpuPercentSystemMetricsTimeseries.chartContainer);
    cpuPercentSystemMetricsTimeseries.createEmptyChart(
      titleText: 'CPU Percentage (%)',
      datasetLabels: ['CPU Percentage (%)']);

    diskUsageSystemMetricsTimeseries= new charts.DailyTimeseriesLineChartView();
    systemChartsTabContent.append(diskUsageSystemMetricsTimeseries.chartContainer);
    diskUsageSystemMetricsTimeseries.createEmptyChart(
      titleText: 'Disk Usage (GB)',
      datasetLabels: ['Disk Usage (GB)']);

    memoryUsageSystemMetricsTimeseries = new charts.DailyTimeseriesLineChartView();
    systemChartsTabContent.append(memoryUsageSystemMetricsTimeseries.chartContainer);
    memoryUsageSystemMetricsTimeseries.createEmptyChart(
      titleText: 'RAM Usage (GB)',
      datasetLabels: ['RAM Usage (GB)']);
  }

  void createSystemEventsCharts(Map<String, List<model.SystemEventsData>> systemEventsProjectsData) {
    systemEventsProjectsData.forEach((projectName, projectData){
      var systemEventsChart = new charts.SystemEventsTimeseriesLineChartView();
      systemChartsTabContent.insertAdjacentElement('beforeBegin', systemEventsChart.chartContainer);
      systemEventsChart.createEmptyChart(
        projectName: projectName,
        titleText: '$projectName [system events]',
        datasetLabels: List.filled(projectData.length, '', growable: true)
      );
      systemEventsCharts.add(systemEventsChart);
    });
  }

  void set stale (bool staleState) {
    if (staleState) {
      _conversationCharts.forEach((chart) => chart.classes.add('stale'));
    } else {
      _conversationCharts.forEach((chart) => chart.classes.remove('stale'));
    }
  }

  List<Element> get _conversationCharts => querySelectorAll('#conversations .chart');

  void toogleTabView(controller.ChartType chartType) {
    contentElement.children.clear();
    _systemTabLink.classes.remove('active');
    _conversationTabLink.classes.remove('active');
    switch (chartType) {
      case controller.ChartType.system:
        contentElement.append(systemChartsTabContent);
        _systemTabLink.classes.add('active');
        projectSelectorView.projectSelector.classes.add('hidden');
      break;
      case controller.ChartType.conversation:
        contentElement.append(conversationChartsTabContent);
        _conversationTabLink.classes.add('active');
        projectSelectorView.projectSelector.classes.remove('hidden');
      break;
    }
  }

  void setUrlFilters(controller.ChartType type, String project, controller.ChartPeriodFilters periodFilter) {
    UrlView.setPageUrlFilters({
      'type': type.toString().split('.')[1],
      'project': project,
      'period-filter': periodFilter.toString().split('.')[1]
    });
  }

  controller.ChartType getChartTypeUrlFilter() {
    String type = UrlView.getPageUrlFilters()['type'];
    return controller.ChartType.values.singleWhere((v) => v.toString() == 'ChartType.$type', orElse: () => null);
  }

  String getProjectFilter() {
    return UrlView.getPageUrlFilters()['project'];
  }

  controller.ChartPeriodFilters getChartPeriodFilter() {
    String periodFilter = UrlView.getPageUrlFilters()['period-filter'];
    return controller.ChartPeriodFilters.values.singleWhere((v) => v.toString() == 'ChartPeriodFilters.$periodFilter', orElse: () => null);
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
