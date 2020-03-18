const functions = require("firebase-functions");
const monitoring = require("@google-cloud/monitoring");

const client = new monitoring.MetricServiceClient();

exports.fetchCPUUtilizationMetrics = functions.https.onRequest(
  async (request, response) => {
    const dataRequest = {
      name: client.projectPath(request.query.projectId),
      filter: 'metric.type="compute.googleapis.com/instance/cpu/utilization"',
      interval: {
        startTime: {
          // Limit results to the last 10 minutes
          seconds: Number(request.query.startTime) || (Date.now() / 1000 - 60 * 10)
        },
        endTime: {
          seconds: Number(request.query.endTime) || (Date.now() / 1000)
        }
      }
    };
    const [timeSeries] = await client.listTimeSeries(dataRequest);
    response.json(timeSeries)
  }
);

exports.fetchCPUUsageTimeMetrics = functions.https.onRequest(
  async (request, response) => {
    
  }
);

exports.fetchRamUsageMetrics = functions.https.onRequest(
  async (request, response) => {
    
  }
);

exports.fetchInstanceUptimeMetrics = functions.https.onRequest(
  async (request, response) => {
    
  }
);
