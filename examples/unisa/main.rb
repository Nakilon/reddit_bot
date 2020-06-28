require "reddit_bot"
subreddit = "unisa".freeze
bot = RedditBot::Bot.new YAML.load(File.read "secrets.yaml"), subreddit: subreddit
twitter = RedditBot::Twitter.init_twitter "unisa"

loop do
  id = bot.new_posts.find do |post|
    /\(https:\/\/twitter\.com\/#{RedditBot::Twitter::TWITTER_ACCOUNT}\/status\/(\d{18,})\)/i =~ post["selftext"] and break $1
  end.to_i
  fail "no tweets found in subreddit" if id.zero? unless ENV["FIRST_RUN"]

  fail unless flair = bot.json(:get, "/r/#{subreddit}/api/link_flair").find do |flair|
    flair["text"] == "Twitter"
  end

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
