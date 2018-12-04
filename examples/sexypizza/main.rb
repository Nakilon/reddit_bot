require_relative "../boilerplate"

BOT = RedditBot::Bot.new YAML.load(File.read "secrets.yaml"), ignore_captcha: true
SUBREDDIT = "sexypizza"

loop do
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

  if text != BOT.json(:get, "/r/#{SUBREDDIT}/wiki/toppings")["data"]["content_md"]
    puts "editing wiki page '/r/#{SUBREDDIT}/wiki/toppings'"
    pp text
    p BOT.json :post,
      "/r/#{SUBREDDIT}/api/wiki/edit",
      page: "toppings",
      content: text
  else
    puts "nothing to change"
  end

  sleep 3600
end
