require_relative "../boilerplate"
SUBREDDIT = "JohnnyMarr"
BOT = RedditBot::Bot.new YAML.load(File.read "secrets.yaml"), subreddit: SUBREDDIT

TWITTER = "Johnny_Marr"
require_relative "twitter"

loop do
  id = BOT.new_posts.find do |post|
    /\(https:\/\/twitter\.com\/#{TWITTER}\/status\/(\d{18,})\)/i =~ post["selftext"] and break $1
  end.to_i
  n = if id.zero?
    fail "no tweets found in subreddit" unless [ "#{SUBREDDIT}_TEST" ].include?(SUBREDDIT) || ENV["START"]
    10
  else
    200
  end

  fail unless flair = BOT.json(:get, "/r/#{SUBREDDIT}/api/link_flair").find do |flair|
    flair["text"] == "Twitter"
  end

  timeout = 0
  JSON.load( begin
    NetHTTPUtils.request_data(
      "https://api.twitter.com/1.1/statuses/user_timeline.json",
      form: { screen_name: TWITTER, count: n, tweet_mode: "extended" },
      header: { Authorization: "Bearer #{TWITTER_ACCESS_TOKEN}" }
    )
  rescue NetHTTPUtils::Error => e
    fail if e.code != 503
    sleep timeout += 1
    retry
  end ).reverse_each do |tweet|
    next if tweet["id"] <= id
    title, text, contains_media = Tweet2titleNtext[tweet]
    result = BOT.json :post, "/api/submit", {
      sr: SUBREDDIT,
      kind: "self",
      title: title,
      text: text,
    }.tap{ |h| h.merge!({ flair_id: flair["id"] }) }
    if result["json"]["errors"].empty?
      abort if ENV["ONCE"]
      next
    end
    fail unless result["json"]["errors"].map(&:first) == ["ALREADY_SUB"]
    puts "ALREADY_SUB error for #{tweet["id"]}"
  end

  puts "END LOOP #{Time.now}"
  sleep 300
end
