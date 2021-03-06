import 'dart:convert';
import 'dart:html';

import 'package:crypto/crypto.dart';
import 'package:chartjs/chartjs.dart' as chartjs;


init() {
  chartjs.ChartTooltipPositioner custom = (List<dynamic> elements, chartjs.Point eventPosition) {
    if (elements.isEmpty) {
      return null;
    }
    return new chartjs.Point(x: eventPosition.x, y: eventPosition.y < 10 ? 10: eventPosition.y);
  };
  chartjs.Chart.Tooltip.positioners.custom = custom;
}

class SingleIndicatorChartView {
  DivElement chartContainer;
  DivElement title;
  DivElement value;
  DivElement spinner;

  SingleIndicatorChartView() {
    chartContainer = new DivElement()
      ..classes.add('chart');

    value = new DivElement()
      ..classes.add('chart__value');
    chartContainer.append(value);

    title = new DivElement()
      ..classes.add('chart__title');
    chartContainer.append(title);

    spinner = createSpinner();
    spinner.classes.add('hidden');
    chartContainer.append(spinner);
  }

  void createEmptyChart({String titleText = ''}) {
    title.text = titleText;
    value.text = '0';
  }

  void updateChart(String newValue) {
    value.text = newValue;
  }
}

class HistogramChartView {
  DivElement chartContainer;
  DivElement title;
  DivElement spinner;
  CanvasElement canvas;
  chartjs.Chart chart;
  chartjs.ChartData chartData;

  HistogramChartView() {
    chartContainer = new DivElement()
      ..classes.add('chart');

    canvas = new CanvasElement(height: 500, width: 800);

    // Wrap the canvas into a <div> element as needed by Chart.js
    chartContainer.append(new DivElement()
      ..classes.add('chart--5080')
      ..append(canvas));

    title = new DivElement()
      ..classes.add('chart__title');
    chartContainer.append(title);

    spinner = createSpinner();
    spinner.classes.addAll(['hidden','chart5080']);
    chartContainer.append(spinner);
  }

  void createEmptyChart({String titleText = '', String datasetLabel = ''}) {
    title.text = titleText;

    var chartDataset = new chartjs.ChartDataSets(
      label: datasetLabel,
      backgroundColor: '#24ABB8',
      data: []);

    chartData = new chartjs.ChartData(labels: [], datasets: [chartDataset]);

    var chartOptions = new chartjs.ChartOptions(
      legend: new chartjs.ChartLegendOptions(display: false),
      scales: new chartjs.LinearScale(yAxes: [
        new chartjs.ChartYAxe()
          ..ticks = (new chartjs.LinearTickOptions()..beginAtZero = true)
          ..gridLines = (new chartjs.GridLineOptions(zeroLineWidth: 0))
        ],
        xAxes: [
          new chartjs.ChartXAxe()..gridLines = (new chartjs.GridLineOptions(zeroLineWidth: 0))
        ]),
      animation: new chartjs.ChartAnimationOptions(duration: 0),
      hover: new chartjs.ChartHoverOptions()..animationDuration = 0
    );

    var chartConfig = new chartjs.ChartConfiguration(type: 'bar', data: chartData, options: chartOptions);
    chart = chartjs.Chart(canvas.getContext('2d'), chartConfig);
  }

  void updateChart(Map<String, int> updatedCountsAtTimestamp) {
    chartData.datasets.first.data
      ..clear()
      ..addAll(updatedCountsAtTimestamp.values);
    chartData.labels
      ..clear()
      ..addAll(updatedCountsAtTimestamp.keys);
    chart.update(new chartjs.ChartUpdateProps(duration: 0));
  }
}

class DailyTimeseriesLineChartView {
  DivElement chartContainer;
  DivElement title;
  DivElement spinner;
  CanvasElement canvas;
  chartjs.Chart chart;
  chartjs.ChartData chartData;

  DailyTimeseriesLineChartView() {
    chartContainer = new DivElement()
      ..classes.add('chart');

    canvas = new CanvasElement(height: 300, width: 800);

    // Wrap the canvas into a <div> element as needed by Chart.js
    chartContainer.append(new DivElement()
      ..classes.add('chart--3080')
      ..append(canvas));

    title = new DivElement()
      ..classes.add('chart__title');
    chartContainer.append(title);

    spinner = createSpinner();
    spinner.classes.addAll(['hidden','chart3080']);
    chartContainer.append(spinner);
  }

  void createEmptyChart({String titleText = '', List<String> datasetLabels = const []}) {
    title.text = titleText;

    List<chartjs.ChartDataSets> chartDatasets = [];
    datasetLabels.forEach((datasetLabel) => {
          chartDatasets.add(new chartjs.ChartDataSets(
              label: datasetLabel,
              backgroundColor: 'rgba(0, 0, 0, 0)',
              borderColor: '#24ABB8',
              data: []))
        });

    chartData = new chartjs.ChartData(labels: [], datasets: chartDatasets);

    var chartOptions = new chartjs.ChartOptions(
      legend: new chartjs.ChartLegendOptions(display: false),
      scales: new chartjs.LinearScale(
        xAxes: [
          new chartjs.ChartXAxe()
            ..type = 'time'
            ..distribution = 'linear'
            ..bounds = 'ticks'
            ..time = (new chartjs.TimeScale(unit: 'day'))
            ..gridLines = (new chartjs.GridLineOptions(zeroLineWidth: 0))
        ],
        yAxes: [
          new chartjs.ChartYAxe()
            ..ticks = (new chartjs.LinearTickOptions()..beginAtZero = true)
            ..gridLines = (new chartjs.GridLineOptions(zeroLineWidth: 0))
        ]),
      hover: new chartjs.ChartHoverOptions()..animationDuration = 0
    );

    var chartConfig = new chartjs.ChartConfiguration(type: 'line', data: chartData, options: chartOptions);
    chart = chartjs.Chart(canvas.getContext('2d'), chartConfig);
  }

  void updateChart(List<Map<DateTime, num>> updatedCountsAtTimestampList, {String timeScaleUnit = 'day', num yLowerLimit = 0, num yUpperLimit, DateTime xLowerLimit, DateTime xUpperLimit}) {
    for (var i = 0; i < updatedCountsAtTimestampList.length; i++) {
      List<chartjs.ChartPoint> timeseriesPoints = [];
      List<DateTime> sortedDateTimes = updatedCountsAtTimestampList[i].keys.toList()
        ..sort((t1, t2) => t1.compareTo(t2));
      for (var datetime in sortedDateTimes) {
        var value = updatedCountsAtTimestampList[i][datetime];
        timeseriesPoints.add(
            new chartjs.ChartPoint(t: datetime.toIso8601String(), y: value));
      }
      chartData.datasets[i].data
        ..clear()
        ..addAll(timeseriesPoints);
    }
    var timeScaleOptions = new chartjs.TimeScale(unit: timeScaleUnit);
    if (timeScaleUnit == 'hour') {
      timeScaleOptions.stepSize = 2;
    }
    chart.options.scales.xAxes[0].time = timeScaleOptions;
    chart.options.scales.xAxes[0].type = 'time';
    chart.options.scales.xAxes[0].ticks.min = xLowerLimit?.toIso8601String();
    chart.options.scales.xAxes[0].ticks.max = xUpperLimit?.toIso8601String();
    if (timeScaleUnit == 'hour') {
      chart.options.scales.xAxes[0].time = (new chartjs.TimeScale()
                                              ..displayFormats = new chartjs.TimeDisplayFormat(hour: 'D/MM hA'));
    }
    chart.options.scales.yAxes[0].ticks.min = yLowerLimit;
    if (yUpperLimit != null) {
      chart.options.scales.yAxes[0].ticks.max = yUpperLimit;
    }
    chart.update(new chartjs.ChartUpdateProps(duration: 0));
  }
}

class SystemEventsTimeseriesLineChartView {
  DivElement chartContainer;
  DivElement title;
  DivElement spinner;
  CanvasElement canvas;
  chartjs.Chart chart;
  chartjs.ChartData chartData;

  SystemEventsTimeseriesLineChartView() {
    chartContainer = new DivElement()
      ..classes.add('chart');

    canvas = new CanvasElement(height: 300, width: 800);

    // Wrap the canvas into a <div> element as needed by Chart.js
    chartContainer.append(new DivElement()
      ..classes.add('chart--3080')
      ..append(canvas));

    title = new DivElement()
      ..classes.add('chart__title');
    chartContainer.append(title);

    spinner = createSpinner();
    spinner.classes.addAll(['hidden', 'chart3080']);
    chartContainer.append(spinner);
  }

  void createEmptyChart({String titleText = '', List<String> datasetLabels = const []}) {
    title.text = titleText;

    List<chartjs.ChartDataSets> chartDatasets = [];
    datasetLabels.forEach((datasetLabel) {
      chartDatasets.add(new chartjs.ChartDataSets(
          label: datasetLabel,
          backgroundColor: 'rgba(36, 171, 184, 0.3)',
          borderColor: '#2B8991',
          data: [],
          showLine: false,
          pointRadius: 8));
      });

    chartData = new chartjs.ChartData(labels: [], datasets: chartDatasets);

    var chartOptions = new chartjs.ChartOptions(
      legend: new chartjs.ChartLegendOptions(display: false),
      scales: new chartjs.LinearScale(
        xAxes: [
          new chartjs.ChartXAxe()
            ..type = 'time'
            ..distribution = 'linear'
            ..bounds = 'ticks'
            ..time = (new chartjs.TimeScale(unit: 'day'))
            ..gridLines = (new chartjs.GridLineOptions(zeroLineWidth: 0))
        ],
        yAxes: [
          new chartjs.ChartYAxe()
            ..ticks = (new chartjs.LinearTickOptions()..beginAtZero = true)
            ..display = false
            ..gridLines = (new chartjs.GridLineOptions(zeroLineWidth: 0))
        ]),
      hover: new chartjs.ChartHoverOptions()..animationDuration = 0
    );

    var chartConfig = new chartjs.ChartConfiguration(type: 'line', data: chartData, options: chartOptions);
    chart = chartjs.Chart(canvas.getContext('2d'), chartConfig);
  }

  void updateChart(Map<String, Map<DateTime, num>> updatedCountsAtTimestampList, {String timeScaleUnit = 'day', num yLowerLimit = 0 , num yUpperLimit, DateTime xLowerLimit, DateTime xUpperLimit}) {
    // Clearing up previous data
    chartData.datasets.clear();

    // Show new data
    updatedCountsAtTimestampList.forEach((datasetLabel, data) {
      List<chartjs.ChartPoint> timeseriesPoints = [];
      List<DateTime> sortedDateTimes = data.keys.toList()
        ..sort((t1, t2) => t1.compareTo(t2));
      for (var datetime in sortedDateTimes) {
        var value = data[datetime];
        timeseriesPoints.add(
            new chartjs.ChartPoint(t: datetime.toIso8601String(), y: value));
      }
      var newChartDataset = new chartjs.ChartDataSets(
        label: datasetLabel,
        backgroundColor: '${_stringToHexColor(datasetLabel)}4D',
        borderColor: _stringToHexColor(datasetLabel),
        data: [],
        showLine: false,
        pointRadius: 8,
        hoverRadius: 8);
      newChartDataset.data.addAll(timeseriesPoints);
      chartData.datasets.add(newChartDataset);
    });
    var timeScaleOptions = new chartjs.TimeScale(unit: timeScaleUnit);
    if (timeScaleUnit == 'hour') {
      timeScaleOptions.stepSize = 2;
    }
    chart.options.scales.xAxes[0].time = timeScaleOptions;
    chart.options.scales.xAxes[0].type = 'time';
    chart.options.scales.xAxes[0].ticks.min = xLowerLimit?.toIso8601String();
    chart.options.scales.xAxes[0].ticks.max = xUpperLimit?.toIso8601String();
    chart.options.scales.yAxes[0].ticks.min = yLowerLimit;
    if (yUpperLimit != null) {
      chart.options.scales.yAxes[0].ticks.max = yUpperLimit;
    }
    chart.update(new chartjs.ChartUpdateProps(duration: 0));
  }

  String _stringToHexColor(str) => '#${md5.convert(utf8.encode(str)).toString().substring(0, 6)}';
}

class DriverTimeseriesBarChartView {
  DivElement chartContainer;
  DivElement title;
  DivElement metricsSelector;
  DivElement xUpperLimitRangeSlider;
  DivElement yUpperLimitRangeSlider;
  DivElement spinner;
  CanvasElement canvas;
  chartjs.Chart chart;
  chartjs.ChartData chartData;

  DriverTimeseriesBarChartView() {
    chartContainer = new DivElement()
      ..classes.add('chart');

    canvas = new CanvasElement(height: 300, width: 800);

    // Wrap the canvas into a <div> element as needed by Chart.js
    chartContainer.append(new DivElement()
      ..classes.add('chart--3080')
      ..append(canvas));

    title = new DivElement()
      ..classes.add('chart__title');
    chartContainer.append(title);

    metricsSelector = new DivElement()..classes.addAll(['driver-metrics-selector', 'dropdown-checkbox']);
    metricsSelector.append(Element.span()
      ..classes.add('anchor')
      ..text = 'Filter Metrics');
    chartContainer.insertAdjacentElement('afterbegin', metricsSelector);

    xUpperLimitRangeSlider = new DivElement()
      ..classes.add('x-range-slider-container')
      ..append(new DivElement()..classes.add('range-value'))
      ..append(
        new RangeInputElement()
        ..value = '0'
        ..step = '1'
        ..min = '1'
        ..onInput.listen((e) {
          var slider = (e.currentTarget as RangeInputElement);
          var sliderIndicator = (e.currentTarget as Element).previousElementSibling;
          var newValue = (int.parse(slider.value) - int.parse(slider.min)) * 100 / (int.parse(slider.max) - int.parse(slider.min));
          var newPosition = 742 - (newValue * 0.1);
          sliderIndicator.children.clear();
          var isoDate = new DateTime.fromMillisecondsSinceEpoch(int.parse(slider.value)).toIso8601String();
          sliderIndicator.append(new Element.span()..text = isoDate);
          sliderIndicator.style.setProperty('right', 'calc(${-newValue}% + (${newPosition}px))');
        })
      )
      ..append(new DivElement()..classes.add('range-value'))
      ..append(
        new RangeInputElement()
        ..value = '1000'
        ..step = '1'
        ..min = '1'
        ..onInput.listen((e) {
          var slider = (e.currentTarget as RangeInputElement);
          var sliderIndicator = (e.currentTarget as Element).previousElementSibling;
          var newValue = (int.parse(slider.value) - int.parse(slider.min)) * 100 / (int.parse(slider.max) - int.parse(slider.min));
          var newPosition = 742 - (newValue * 0.1);
          sliderIndicator.children.clear();
          var isoDate = new DateTime.fromMillisecondsSinceEpoch(int.parse(slider.value)).toIso8601String();
          sliderIndicator.append(new Element.span()..text = isoDate);
          sliderIndicator.style.setProperty('right', 'calc(${-newValue}% + (${newPosition}px))');
        })
      );
    chartContainer.append(xUpperLimitRangeSlider);

    yUpperLimitRangeSlider = new DivElement()
      ..classes.add('y-range-slider-container')
      ..append(new DivElement()..classes.add('range-value'))
      ..append(
        new RangeInputElement()
        ..value = '0'
        ..step = '1'
        ..min = '1'
        ..onInput.listen((e) {
          var slider = (e.currentTarget as RangeInputElement);
          var sliderIndicator = (e.currentTarget as Element).previousElementSibling;
          var newValue = (int.parse(slider.value) - int.parse(slider.min)) * 100 / (int.parse(slider.max) - int.parse(slider.min));
          var newPosition = 150 - (newValue * 2.15);
          sliderIndicator.children.clear();
          sliderIndicator.append(new Element.span()..text = slider.value);
          sliderIndicator.style.setProperty('top', 'calc(${-newValue}% + (${newPosition}px))');
        })
      );
    chartContainer.append(yUpperLimitRangeSlider);

    spinner = createSpinner();
    spinner.classes.addAll(['hidden', 'chart3080']);
    chartContainer.append(spinner);
  }

  void createEmptyChart({String titleText = '', List<String> datasetLabels = const []}) {
    title.text = titleText;

    List<chartjs.ChartDataSets> chartDatasets = [];
    datasetLabels.forEach((datasetLabel) {
      chartDatasets.add(new chartjs.ChartDataSets(
          label: datasetLabel,
          backgroundColor: 'rgba(36, 171, 184, 0.3)',
          borderColor: '#2B8991',
          data: [],
          showLine: false,
          pointRadius: 8));
      });

    chartData = new chartjs.ChartData(labels: [], datasets: chartDatasets);

    var chartOptions = new chartjs.ChartOptions(
      legend: new chartjs.ChartLegendOptions(display: false),
      scales: new chartjs.LinearScale(
        xAxes: [
          new chartjs.ChartXAxe()
            ..type = 'time'
            ..distribution = 'linear'
            ..bounds = 'ticks'
            ..time = (new chartjs.TimeScale(unit: 'day'))
            ..gridLines = (new chartjs.GridLineOptions(zeroLineWidth: 0))
        ],
        yAxes: [
          new chartjs.ChartYAxe()
            ..ticks = (new chartjs.LinearTickOptions()..beginAtZero = true)
            ..gridLines = (new chartjs.GridLineOptions(zeroLineWidth: 0))
        ]),
      hover: new chartjs.ChartHoverOptions()..animationDuration = 0,
      tooltips: new chartjs.ChartTooltipOptions()..mode = 'index',
    );

    var chartConfig = new chartjs.ChartConfiguration(type: 'bar', data: chartData, options: chartOptions);
    chart = chartjs.Chart(canvas.getContext('2d'), chartConfig);
  }

  void updateChart(Map<String, Map<DateTime, num>> updatedCountsAtTimestampList, {String timeScaleUnit = 'day', num yLowerLimit = 0 , num yUpperLimit, DateTime xLowerLimit, DateTime xUpperLimit}) {
    // Clearing up previous data
    chartData.datasets.clear();

    // Show new data
    updatedCountsAtTimestampList.forEach((datasetLabel, data) {
      List<chartjs.ChartPoint> timeseriesPoints = [];
      List<DateTime> sortedDateTimes = data.keys.toList()
        ..sort((t1, t2) => t1.compareTo(t2));
      for (var datetime in sortedDateTimes) {
        var value = data[datetime];
        timeseriesPoints.add(
            new chartjs.ChartPoint(t: datetime.toIso8601String(), y: value));
      }
      var newChartDataset = new chartjs.ChartDataSets(
        label: datasetLabel,
        backgroundColor: '${_stringToHexColor(datasetLabel)}',
        borderColor: '${_stringToHexColor(datasetLabel)}',
        data: [],
        showLine: false,
        pointRadius: 2,
        hoverRadius: 4,
        spanGaps: false,
        barPercentage: 1.1,
        categoryPercentage: 1.1,
        barThickness: ((chart.chartArea.right - chart.chartArea.left) / xUpperLimit.difference(xLowerLimit).inMinutes));
      newChartDataset.data.addAll(timeseriesPoints);
      chartData.datasets.add(newChartDataset);
    });
    var timeScaleOptions = new chartjs.TimeScale(unit: timeScaleUnit);
    if (timeScaleUnit == 'hour') {
      timeScaleOptions.stepSize = 2;
    }
    if (xUpperLimit.difference(xLowerLimit).inHours <= 3) {
      timeScaleOptions.unit = 'minute';
      timeScaleOptions.displayFormats = new chartjs.TimeDisplayFormat(hour: 'D/MM h:mm a');
      timeScaleOptions.stepSize = 15;
    } else if (xUpperLimit.difference(xLowerLimit).inHours <= 12) {
      timeScaleOptions.stepSize = 1;
    }
    chart.options.scales.xAxes[0].time = timeScaleOptions;
    chart.options.scales.xAxes[0].type = 'time';
    chart.options.scales.xAxes[0].ticks.min = xLowerLimit?.toIso8601String();
    chart.options.scales.xAxes[0].ticks.max = xUpperLimit?.toIso8601String();
    chart.options.scales.xAxes[0].stacked = true;

    chart.options.tooltips.position = 'custom';

    chart.options.scales.yAxes[0].stacked = true;
    chart.options.scales.yAxes[0].ticks.min = yLowerLimit;
    if (yUpperLimit != null) {
      chart.options.scales.yAxes[0].ticks.max = yUpperLimit;
    }
    chart.update(new chartjs.ChartUpdateProps(duration: 0));
  }

  String _stringToHexColor(str) => '#${md5.convert(utf8.encode(str)).toString().substring(0, 6)}';
}

class SystemMetricsTimeseriesBarChartView {
  DivElement chartContainer;
  DivElement title;
  DivElement spinner;
  CanvasElement canvas;
  chartjs.Chart chart;
  chartjs.ChartData chartData;

  SystemMetricsTimeseriesBarChartView() {
    chartContainer = new DivElement()
      ..classes.add('chart');

    canvas = new CanvasElement(height: 300, width: 800);

    // Wrap the canvas into a <div> element as needed by Chart.js
    chartContainer.append(new DivElement()
      ..classes.add('chart--3080')
      ..append(canvas));

    title = new DivElement()
      ..classes.add('chart__title');
    chartContainer.append(title);

    spinner = createSpinner();
    spinner.classes.addAll(['hidden','chart3080']);
    chartContainer.append(spinner);
  }

  void createEmptyChart({String titleText = '', List<String> datasetLabels = const []}) {
    title.text = titleText;

    List<chartjs.ChartDataSets> chartDatasets = [];
    datasetLabels.forEach((datasetLabel) {
      chartDatasets.add(new chartjs.ChartDataSets(
          label: datasetLabel,
          backgroundColor: '#24ABB8',
          borderColor: '#24ABB8',
          data: [],
          showLine: false,
          pointRadius: 8));
      });

    chartData = new chartjs.ChartData(labels: [], datasets: chartDatasets);

    var chartOptions = new chartjs.ChartOptions(
      legend: new chartjs.ChartLegendOptions(display: false),
      scales: new chartjs.LinearScale(
        xAxes: [
          new chartjs.ChartXAxe()
            ..type = 'time'
            ..distribution = 'linear'
            ..bounds = 'ticks'
            ..time = (new chartjs.TimeScale(unit: 'day'))
            ..gridLines = (new chartjs.GridLineOptions(zeroLineWidth: 0))
        ],
        yAxes: [
          new chartjs.ChartYAxe()
            ..ticks = (new chartjs.LinearTickOptions()..beginAtZero = true)
            ..gridLines = (new chartjs.GridLineOptions(zeroLineWidth: 0))
        ]),
      hover: new chartjs.ChartHoverOptions()..animationDuration = 0,
      tooltips: new chartjs.ChartTooltipOptions()..mode = 'x-axis',
    );

    var chartConfig = new chartjs.ChartConfiguration(type: 'bar', data: chartData, options: chartOptions);
    chart = chartjs.Chart(canvas.getContext('2d'), chartConfig);
  }

  void updateChart(List<Map<DateTime, num>> updatedCountsAtTimestampList, {String timeScaleUnit = 'day', num yLowerLimit = 0 , num yUpperLimit, DateTime xLowerLimit, DateTime xUpperLimit}) {
    for (var i = 0; i < updatedCountsAtTimestampList.length; i++) {
      List<chartjs.ChartPoint> timeseriesPoints = [];
      List<DateTime> sortedDateTimes = updatedCountsAtTimestampList[i].keys.toList()
        ..sort((t1, t2) => t1.compareTo(t2));
      for (var datetime in sortedDateTimes) {
        var value = updatedCountsAtTimestampList[i][datetime];
        timeseriesPoints.add(
            new chartjs.ChartPoint(t: datetime.toIso8601String(), y: value));
      }
      chartData.datasets[i].data
        ..clear()
        ..addAll(timeseriesPoints);

      chartData.datasets[i]
        ..barPercentage = 1.0
        ..categoryPercentage = 1.4;
    }
    var timeScaleOptions = new chartjs.TimeScale(unit: timeScaleUnit);
    if (timeScaleUnit == 'hour') {
      timeScaleOptions.stepSize = 2;
    }
    chart.options.scales.xAxes[0].time = timeScaleOptions;
    chart.options.scales.xAxes[0].type = 'time';
    chart.options.scales.xAxes[0].ticks.min = xLowerLimit?.toIso8601String();
    chart.options.scales.xAxes[0].ticks.max = xUpperLimit?.toIso8601String();
    if (timeScaleUnit == 'hour') {
      chart.options.scales.xAxes[0].time = (new chartjs.TimeScale()
                                              ..displayFormats = new chartjs.TimeDisplayFormat(hour: 'D/MM hA'));
    }
    chart.options.scales.yAxes[0].ticks.min = yLowerLimit;
    if (yUpperLimit != null) {
      chart.options.scales.yAxes[0].ticks.max = yUpperLimit;
    }
    chart.update(new chartjs.ChartUpdateProps(duration: 0));
  }
}

// Util methods

DivElement createSpinner() {
  return new DivElement()
    ..classes.add('sk-fading-circle')
    ..append(new DivElement()..classes.addAll(['sk-circle1', 'sk-circle']))
    ..append(new DivElement()..classes.addAll(['sk-circle2', 'sk-circle']))
    ..append(new DivElement()..classes.addAll(['sk-circle3', 'sk-circle']))
    ..append(new DivElement()..classes.addAll(['sk-circle4', 'sk-circle']))
    ..append(new DivElement()..classes.addAll(['sk-circle5', 'sk-circle']))
    ..append(new DivElement()..classes.addAll(['sk-circle6', 'sk-circle']))
    ..append(new DivElement()..classes.addAll(['sk-circle7', 'sk-circle']))
    ..append(new DivElement()..classes.addAll(['sk-circle8', 'sk-circle']))
    ..append(new DivElement()..classes.addAll(['sk-circle9', 'sk-circle']))
    ..append(new DivElement()..classes.addAll(['sk-circle10', 'sk-circle']))
    ..append(new DivElement()..classes.addAll(['sk-circle11', 'sk-circle']))
    ..append(new DivElement()..classes.addAll(['sk-circle12', 'sk-circle']));
}
