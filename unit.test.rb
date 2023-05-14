require_relative "lib/reddit_bot"

# require "minitest/mock"
require "webmock/minitest"
require "webmockdump"
WebMock.enable!

require "minitest/autorun"
require_relative "schema"
describe RedditBot do
  it "" do
    stub_request(:post, "https://www.reddit.com/api/v1/access_token").to_return \
      body: '{"access_token": "qwerty", "token_type": "bearer", "expires_in": 86400, "scope": "*"}'
    stub_request(:get, "https://oauth.reddit.com/api/v1/me?api_type=json").to_return \
      body: JSON.dump(Nakischema.fixture(Schema[:body])),
      headers: Nakischema.fixture(Schema[:header])
    RedditBot::Bot.new(YAML.load File.read "examples/nakibot.secrets.yaml").json :get, "/api/v1/me"
  end
end
