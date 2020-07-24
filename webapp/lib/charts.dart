import 'dart:convert';
import 'dart:html';

import 'package:crypto/crypto.dart';
import 'package:chartjs/chartjs.dart' as chartjs;

class SingleIndicatorChartView {
  DivElement chartContainer;
  DivElement title;
  DivElement value;

  SingleIndicatorChartView() {
    chartContainer = new DivElement()
      ..classes.add('chart');

    value = new DivElement()
      ..classes.add('chart__value');
    chartContainer.append(value);

    title = new DivElement()
      ..classes.add('chart__title');
    chartContainer.append(title);
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
      tooltips: new chartjs.ChartTooltipOptions()..mode = 'x-axis',
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
        barPercentage: 1.0,
        barThickness: 750 / xUpperLimit.difference(xLowerLimit).inMinutes);
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
    chart.options.scales.xAxes[0].stacked = true;

    chart.options.scales.yAxes[0].stacked = true;
    chart.options.scales.yAxes[0].ticks.min = yLowerLimit;
    if (yUpperLimit != null) {
      chart.options.scales.yAxes[0].ticks.max = yUpperLimit;
    }
    chart.update(new chartjs.ChartUpdateProps(duration: 0));
  }

  String _stringToHexColor(str) => '#${md5.convert(utf8.encode(str)).toString().substring(0, 6)}';
}
