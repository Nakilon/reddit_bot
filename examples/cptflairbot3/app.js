exports.casualpokemontrades = function(event, callback) {

  // based on https://www.tomas-dvorak.cz/posts/nodejs-request-without-dependencies/
  const getContent = function(url) {
    return new Promise((resolve, reject) => {
      const lib = url.startsWith("https") ? require("https") : require("http");
      const request = function(url) {
        lib.get(url, (response) => {
          var body = [];
          /*if (response.statusCode == 302) {
            body = [];
            request(response.headers.location);
          } else*/ if (response.statusCode < 200 || response.statusCode > 299) {
            reject(new Error("Failed to load page, status code: " + response.statusCode));
          } else {
            response.on("data", (chunk) => body.push(chunk));
            response.on("end", () => resolve(body.join("")));
          };
        } ).on("error", (err) => reject(err));
      };
      request(url);
    } );
  };

  const storage = require("@google-cloud/storage")();
  storage.
    bucket("casualpokemontrades.function.nakilon.pro").
    file("gas_hook_id.secret").
    download( function(err, contents) {
      const log_payload = JSON.parse(Buffer.from(event.data.data, "base64").toString()).jsonPayload;
      console.log(log_payload);
      const path = "https://script.google.com/macros/s/" + contents.toString() + "/exec?payload=" + Buffer.from(JSON.stringify(log_payload)).toString("base64");
      console.log(path);
      getContent(path);
        // then((html) => console.log(html)).
        // catch((err) => console.error(err));
    } );

  callback();
};
