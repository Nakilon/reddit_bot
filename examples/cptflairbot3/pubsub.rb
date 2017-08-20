# this emulates a Pub/Sub message from a 'casualpokemontrades' Sink for a deployed Function in Emulator as
# `GOOGLE_APPLICATION_CREDENTIALS="***.json" functions start`
# `functions deploy casualpokemontrades --trigger-topic casualpokemontrades`
# it waits for JSON payload from STDIN -- enter `{}` to use default payload sample
# after that you may wanna do `tail -30 /usr/local/lib/node_modules/@google-cloud/functions-emulator/logs/cloud-functions-emulator.log`
# to really deploy the Function do `gcloud beta functions deploy casualpokemontrades --stage-bucket casualpokemontrades.function.nakilon.pro --trigger-topic casualpokemontrades`

require "base64"
require "json"

base64 = Base64.strict_encode64 JSON.dump(
  {
    "insertId"=>"dbkwdqg109zgse",
    "jsonPayload"=>{
      "css_class"=>"charizard",
      "messaged_at"=>"2017-08-19 10:11:57 +0300",
      "name"=>"nakilon",
      "processed_at"=>"2017-08-19 12:18:46 +0300",
      "text"=>"0000-0000-0000 | test"
    }.merge(JSON.load gets),
    "labels"=>{"subreddit"=>"casualpokemontrades"},
    "logName"=>"projects/nakilonpro/logs/cptflairbot3",
    "receiveTimestamp"=>"2017-08-19T09:18:47.260056855Z",
    "resource"=>{"labels"=>{"project_id"=>"nakilonpro"}, "type"=>"global"},
    "severity"=>"WARNING",
    "timestamp"=>"2017-08-19T09:18:46.666079Z"
  }
)

exec 'functions call casualpokemontrades --data=\'{"data":"' + base64 + '","attributes":{"logging.googleapis.com/timestamp":"2017-08-19T09:18:46.666079Z"},"@type":"type.googleapis.com/google.pubsub.v1.PubsubMessage"}\''
