cache = lambda do |&block|
  require "yaml"
  next YAML.load File.read "cache.yaml" if File.exist? "cache.yaml"
  block.call.tap do |data|
    File.write "cache.yaml", YAML.dump(data)
  end
end


require_relative "../boilerplate"
BOT = RedditBot::Bot.new YAML.load File.read "secrets.yaml"

SUBREDDIT = "largeimages"

table = cache.call do
  BOT.json(:get, "/r/#{SUBREDDIT}/about/log", [["limit", 500]])["data"]["children"].map do |child|
    fail child unless child["kind"] == "modaction"
    next unless %w{ removelink approvelink }.include? child["data"]["action"]
    title = BOT.json(:get, "/api/info", [["id", child["data"]["target_fullname"]]])["data"]["children"][0]["data"]["title"]
    [child["data"]["action"], title[/(?<=^\[)\d+x\d+/], title[/[^\/]+$/]]
  end.compact
end

report = table.group_by(&:last).sort_by{ |_, group| -group.size }.map do |sub, group|
  good = (group.group_by(&:first)["approvelink"] || []).size
  [sub, "Total: #{group.size}", "Quality: #{good * 100 / group.size}%"]
end


require "mll"

puts MLL::grid[report.take(20), spacings: [3, 0]]
