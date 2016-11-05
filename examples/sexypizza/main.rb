require_relative "../boilerplate"

BOT = RedditBot::Bot.new YAML.load(File.read "secrets.yaml"), ignore_captcha: true
SUBREDDIT = "sexypizza"

loop do
  Hearthbeat.beat "u_SexyPizzaBot_r_sexypizza", 3610 unless Gem::Platform.local.os == "darwin"
  puts "LOOP #{Time.now}"

  flairs = BOT.json(:get, "/r/#{SUBREDDIT}/api/flairlist", {limit: 1000})["users"]

  text = \
    "**Vote with your flair!**\n\n" +
    "Type of pizza | Number of lovers\n" +
    "--------------|-----------------\n" +
    flairs.
      group_by{ |flair| flair["flair_text"] }.
      sort_by{ |_, group| -group.size }.
      map{ |flair, group| "#{flair} | #{group.size}" }.
      join("\n")
  puts text

  p BOT.wiki_edit SUBREDDIT, "toppings", text

  sleep 3600
end
