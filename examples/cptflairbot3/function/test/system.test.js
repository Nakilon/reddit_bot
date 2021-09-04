// TODO: maybe rewrite this test (and maybe the function) to Ruby?

describe("system tests", () => {
  it("should be ok", async () => {
    const moment = require("moment");
    const startTime = moment().subtract(4, "minutes").toISOString();

    const {PubSub} = require("@google-cloud/pubsub");
    const pubsub = new PubSub();
    const topicName = "casualpokemontrades-test";
    const topic = pubsub.topic(topicName);
    await topic.publish( Buffer.from( JSON.stringify(
      {
        "insertId": "2i936lf6kucec", // TODO: add UUID (restore the uuid function usage from the github sample)
        "jsonPayload": {
          "css_class": "bulbasaur",
          "messaged_at": "2021-09-03 23:39:56 +0000",
          "name": "nakilon",
          "processed_at": "2021-09-03 23:40:34 +0000",
          "text": "0000-0000-0000 | nakilon"
        },
        "labels": {
          "subreddit": "casualpokemontrades"
        },
        "logName": "blablabla",
        "receiveTimestamp": "2021-09-03T23:40:34.632272847Z",
        "resource": {
          "labels": {
            "instance_id": "",
            "project_id": "blablabla",
            "zone": ""
          },
          "type": "gce_instance"
        },
        "severity": "WARNING",
        "timestamp": "2021-09-03T23:40:34.60340163Z"
      }
    ) ) );
    console.log("published");

    const promiseRetry = require("promise-retry");
    await promiseRetry(retry => {
      const assert = require("assert");
      const childProcess = require("child_process");
      const logs = childProcess
        .execSync(`gcloud functions logs read casualpokemontrades-test --start-time ${startTime}`)
        .toString();
      try {
        assert.ok(logs.includes("2i936lf6kucec"));
      } catch (err) {
        retry(err);
      }
    });
  });
});
