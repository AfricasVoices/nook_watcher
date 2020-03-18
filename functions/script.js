const monitoring = require("@google-cloud/monitoring");

const client = new monitoring.MetricServiceClient();

(async () => {
  try {
    const dataRequest = {
      name: client.projectPath("lively-math-271003"),
      filter: 'metric.type="compute.googleapis.com/instance/cpu/utilization"',
      interval: {
        startTime: {
          // Limit results to the last 20 minutes
          seconds: Date.now() / 1000 - 60 * 20
        },
        endTime: {
          seconds: Date.now() / 1000
        }
      }
    };
    const [timeSeries] = await client.listTimeSeries(dataRequest);
    console.log(timeSeries)
    // timeSeries.forEach(data => {
    //   console.log(`${data.metric.labels.instance_name}:`);
    //   data.points.forEach(point => {
    //     console.log(JSON.stringify(point.value));
    //   });
    // });
  } catch (err) {
    throw err;
  }
})();
