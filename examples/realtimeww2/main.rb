require_relative "../boilerplate"

require "nethttputils"
TWITTER_ACCESS_TOKEN = JSON.load(
  NetHTTPUtils.request_data "https://api.twitter.com/oauth2/token", :post,
    auth: File.read("twitter.token").split,
    form: {grant_type: :client_credentials}
)["access_token"]

SUBREDDIT = "RealTimeWW2_TEST"
BOT = RedditBot::Bot.new YAML.load(File.read "secrets.yaml"), subreddit: SUBREDDIT

TWITTER = "RealTimeWWII"
loop do
  id = BOT.new_posts.find do |post|
    /\Ahttps:\/\/twitter\.com\/#{TWITTER}\/status\/(\d{18,})\z/i =~ post["url"] and break $1
  end.to_i
  fail "no tweets found in subreddit" if id.zero? unless %w{ RealTimeWW2_TEST }.include? SUBREDDIT

  JSON.load( NetHTTPUtils.request_data("https://api.twitter.com/1.1/statuses/user_timeline.json?screen_name=#{TWITTER}&count=200&tweet_mode=extended",
      header: { Authorization: "Bearer #{TWITTER_ACCESS_TOKEN}" }) do |res|
    remaining = res.fetch("x-rate-limit-remaining").to_i
    next if 100 < remaining
    t = (res.fetch("x-rate-limit-reset").to_i - Time.now.to_i + 1).fdiv remaining
    puts "sleep #{t}"
    sleep t
  end ).reverse_each do |tweet|
    next if tweet["id"] <= id
    # tweet["entities"]["urls"].first["url"],
    # (tweet["entities"]["media"].first["media_url_https"] if tweet["entities"]["media"]),
    result = BOT.json :post, "/api/submit", {
      kind: "link",
      url: "https://twitter.com/#{TWITTER}/status/#{tweet["id"]}",
      sr: SUBREDDIT,
      title: tweet["full_text"].sub(/ https:\/\/t\.co\/[0-9a-zA-Z]{10}\z/, ""),
    }
    pp result
    fail unless result["json"]["errors"].empty?
  end

  puts "END LOOP #{Time.now}"
  sleep 300
end
