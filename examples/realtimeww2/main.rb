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
tweet2text = lambda do |tweet|
  CGI::unescapeHTML(tweet["full_text"]).sub(/ https:\/\/t\.co\/[0-9a-zA-Z]{10}\z/, "").tap do |text|
    up = ->s{ s.split.map{ |w| "^#{w}" }.join " " }
    text.concat "\n\n^- #{
      up[tweet["user"]["name"]]
    } [^\\(@#{TWITTER}\\)](https://twitter.com/#{TWITTER}) ^| [#{
      up[Date.parse(tweet["created_at"]).strftime "%B %-d, %Y"]
    }](https://twitter.com/#{TWITTER}/status/#{tweet["id"]})"
    if tweet["entities"]["media"]
      text.concat "\n\nMedia"
      tweet["entities"]["media"].each_with_index do |media, i|
        text.concat "\n\n* [Image #{i + 1}](#{media["media_url_https"]})"
      end
    end
  end
end
test = "The Polish government & military high command is now evacuating Warsaw for Brest, 120 miles east: German armies are too close to the capital\n\n^- ^WW2 ^Tweets ^from ^1939 [^\\(@RealTimeWWII\\)](https://twitter.com/RealTimeWWII) ^| [^September ^7, ^2017](https://twitter.com/RealTimeWWII/status/905764294687633408)\n\nMedia\n\n* [Image 1](https://pbs.twimg.com/media/DJHq71BXYAA6KJ0.jpg)"
fail unless ( tweet2text.call JSON.load NetHTTPUtils.request_data(
  "https://api.twitter.com/1.1/statuses/show.json?id=905764294687633408&tweet_mode=extended",
  header: { Authorization: "Bearer #{TWITTER_ACCESS_TOKEN}" }
) ) == test

loop do
  id = BOT.new_posts.find do |post|
    /\(https:\/\/twitter\.com\/#{TWITTER}\/status\/(\d{18,})\)/i =~ post["selftext"] and break $1
  end.to_i
  fail "no tweets found in subreddit" if id.zero? unless %w{ RealTimeWW2_TEST }.include? SUBREDDIT

  JSON.load( NetHTTPUtils.request_data("https://api.twitter.com/1.1/statuses/user_timeline.json?screen_name=#{TWITTER}&count=200&tweet_mode=extended",
    header: { Authorization: "Bearer #{TWITTER_ACCESS_TOKEN}" }
  ) do |res|
    next unless res.key? "x-rate-limit-remaining"
    remaining = res.fetch("x-rate-limit-remaining").to_i
    next if 100 < remaining
    t = (res.fetch("x-rate-limit-reset").to_i - Time.now.to_i + 1).fdiv remaining
    puts "sleep #{t}"
    sleep t
  end ).reverse_each do |tweet|
    next if tweet["id"] <= id
    # next unless tweet["id"] == 905724018996772865    # two media files
    # tweet["entities"]["urls"].first["url"],
    result = BOT.json :post, "/api/submit", {
      sr: SUBREDDIT,
      kind: "self",
      title: CGI::unescapeHTML(tweet["full_text"]).sub(/ https:\/\/t\.co\/[0-9a-zA-Z]{10}\z/, ""),
      text: tweet2text[tweet],
    }
    pp result
    next if result["json"]["errors"].empty?
    fail unless result["json"]["errors"].map(&:first) == ["ALREADY_SUB"]
    puts "ALREADY_SUB error for #{tweet["id"]}"
  end

  puts "END LOOP #{Time.now}"
  sleep 300
end
