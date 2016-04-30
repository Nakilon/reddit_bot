require_relative "../boilerplate"

SUBREDDIT = "sexypizza"
BOT = RedditBot::Bot.new YAML.load(File.read "secrets.yaml"), ignore_captcha: true#, subreddit: SUBREDDIT


loop do
  AWSStatus::touch
  puts "LOOP #{Time.now}"

  flairs = BOT.json(:get, "/r/#{SUBREDDIT}/api/flairlist", {limit: 1000})["users"]

  text = \
    "**Vote with your flair!**\n\n" +
    "Type of pizza | Number of lovers\n" +
    "--------------|-----------------\n" +
    flairs.
      group_by{ |flair| flair["flair_text"] }.
      # reject{ |flair, | flair.empty? }.
      sort_by{ |_, group| -group.size }.
      map{ |flair, group| "#{flair} | #{group.size}" }.
      # map{ |flair, group| "#{flair} | #{group.size} | #{group.map{ |u| u["user"] }.join ", "}" }.
      join("\n")
  puts text

  p BOT.wiki_edit SUBREDDIT, "toppings", text

  sleep 3600
end
