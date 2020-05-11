import 'dart:html';
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
        ],
        yAxes: [
          new chartjs.ChartYAxe()
            ..ticks = (new chartjs.LinearTickOptions()..beginAtZero = true)
        ]),
      hover: new chartjs.ChartHoverOptions()..animationDuration = 0
    );

    var chartConfig = new chartjs.ChartConfiguration(type: 'line', data: chartData, options: chartOptions);
    chart = chartjs.Chart(canvas.getContext('2d'), chartConfig);
  }

  void updateChart([List<Map<DateTime, dynamic>> updatedCountsAtTimestampList, String timeScaleUnit = 'day']) {
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
    chart.options.scales.xAxes[0].time = (new chartjs.TimeScale(unit: timeScaleUnit));
    chart.update(new chartjs.ChartUpdateProps(duration: 0));
  }
}

 class SystemEventsTimeseriesLineChartView extends DailyTimeseriesLineChartView {
   @override void createEmptyChart({String titleText = '', List<String> datasetLabels = const []}) {
    title.text = titleText;

    List<chartjs.ChartDataSets> chartDatasets = [];
    datasetLabels.forEach((datasetLabel) => {
          chartDatasets.add(new chartjs.ChartDataSets(
              label: datasetLabel,
              backgroundColor: 'rgba(36, 171, 184, 0.3)',
              borderColor: '#2B8991',
              data: [],
              showLine: false,
              pointRadius: 8))
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
        ],
        yAxes: [
          new chartjs.ChartYAxe()
            ..ticks = (new chartjs.LinearTickOptions()
              ..beginAtZero = true
              ..max = 2)
              ..display = false
        ]),
      hover: new chartjs.ChartHoverOptions()..animationDuration = 0
    );

    var chartConfig = new chartjs.ChartConfiguration(type: 'line', data: chartData, options: chartOptions);
    chart = chartjs.Chart(canvas.getContext('2d'), chartConfig);
  }
 }
