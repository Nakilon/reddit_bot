require "reddit_bot"
subreddit = "dut".freeze
bot = RedditBot::Bot.new YAML.load(File.read "secrets.yaml"), subreddit: subreddit
RedditBot::Twitter.init_twitter "DUT_Tweets"

loop do
  bot.json(:get, "/message/unread")["data"]["children"].each do |msg|
    next unless %w{ nakilon technomod }.include? msg["data"]["author"]
    abort "ordered to die" if %w{ die die } == msg["data"].values_at("subject", "body")
  end

  id = bot.new_posts.map do |post|
    post["selftext"].scan(/\(https:\/\/twitter\.com\/#{RedditBot::Twitter::TWITTER_ACCOUNT}\/status\/(\d{18,})\)/i).flatten.map(&:to_i).max
  end.find(&:itself)
  abort "no tweets found in subreddit" if id.zero? unless ENV["FIRST_RUN"]
  abort "flair isn't available" unless flair = bot.json(:get, "/r/#{subreddit}/api/link_flair").find{ |flair| flair["text"] == "Twitter" }

  timeline = RedditBot::Twitter.user_timeline
  timeline.replace timeline.take 2 if ENV["FIRST_RUN"]  # against 200 posts long flood
  timeline.reverse_each do |tweet|
    next if tweet["id"] <= id
    title, text, _ = RedditBot::Twitter.tweet2titleNtext tweet
    result = bot.json :post, "/api/submit", {
      sr: subreddit,
      kind: "self",
      title: title,
      text: text,
      flair_id: flair["id"],
    }
    p result
    if result["json"]["errors"].empty?
      abort "OK" if ENV["ONCE"]
      next
    end
    fail unless result["json"]["errors"].map(&:first) == ["ALREADY_SUB"]
    puts "ALREADY_SUB error for #{tweet["id"]}"
  end

  puts "END LOOP #{Time.now}"
  sleep 300
end
