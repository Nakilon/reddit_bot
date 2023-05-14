require_relative "lib/reddit_bot"
require_relative "schema"
t = RedditBot::Bot.new(YAML.load File.read "examples/nakibot.secrets.yaml").method(:resp_with_token).call(:get, "/api/v1/me", {})
Nakischema.validate JSON.load(t), Schema[:body]
Nakischema.validate t.instance_variable_get(:@last_response).each_header.to_h, Schema[:header]
