const admin = require("firebase-admin");
const functions = require("firebase-functions");
const monitoring = require("@google-cloud/monitoring");

admin.initializeApp();
let db = admin.firestore();
const client = new monitoring.MetricServiceClient();

exports.fetchAllMetrics = functions.pubsub
  .schedule("every 10 minutes")
  .onRun(context => {
    let projectId = process.env.GCLOUD_PROJECT || 'YOUR_PROJECT_ID';
    fetchCPUUtilizationMetrics(projectId);
    fetchCPUUsageTimeMetrics(projectId);
    return null;
  });

async function fetchCPUUtilizationMetrics(projectId) {
  const dataRequest = {
    name: client.projectPath(projectId),
    filter: 'metric.type="compute.googleapis.com/instance/cpu/utilization"',
    interval: {
      startTime: {
        // Limit results to the last 10 minutes
        seconds: Date.now() / 1000 - 60 * 10
      },
      endTime: {
        seconds: Date.now() / 1000
      }
    }
  };
  const [timeSeries] = await client.listTimeSeries(dataRequest);

  let metrics = getFormattedMetrics(timeSeries);

  for (let metric of metrics) {
    try {
      await db.collection("cpu_utilization_metric").add(metric);
    } catch (error) {
      console.error(error);
    }
  }
}

async function fetchCPUUsageTimeMetrics(projectId) {
  const dataRequest = {
    name: client.projectPath(projectId),
    filter: 'metric.type="compute.googleapis.com/instance/cpu/usage_time"',
    interval: {
      startTime: {
        // Limit results to the last 10 minutes
        seconds: Date.now() / 1000 - 60 * 10
      },
      endTime: {
        seconds: Date.now() / 1000
      }
    }
  };
  const [timeSeries] = await client.listTimeSeries(dataRequest);

  let metrics = getFormattedMetrics(timeSeries);

  for (let metric of metrics) {
    try {
      await db.collection("cpu_usage_time_metric").add(metric);
    } catch (error) {
      console.error(error);
    }
  }
}

function getFormattedMetrics(timeSeries) {
  return timeSeries
    .map(series => {
      let instanceName = series.metric.labels["instance_name"];
      return series.points.map(point => {
        return {
          instanceName: instanceName,
          datetime: new Date(
            point.interval.endTime.seconds * 1000
          ).toISOString(),
          value: point.value.doubleValue
        };
      });
    })
    .flat();
}
