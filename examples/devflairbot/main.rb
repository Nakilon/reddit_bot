# The bot changes the post flair class with one with "dev" prefix
#   if there is response from someone with "developer" user flair in comments.
# Seems like in current implementation it reads 10 last comments per subreddit
#   so it's possible to miss if bot is down for a while but in fact it's enough stable and does not go down.

require_relative "../boilerplate"
BOT = RedditBot::Bot.new YAML.load_file "secrets.yaml"

fail("no ENV['ERROR_REPORTING_KEYFILE'] specified") unless ENV["ERROR_REPORTING_KEYFILE"]
require "google/cloud/error_reporting"
Google::Cloud::ErrorReporting.configure do |config|
  config.project_id = (JSON.load File.read ENV["ERROR_REPORTING_KEYFILE"])["project_id"]
end

reported = []
loop do
  puts "LOOP #{Time.now}"

  moderated = BOT.json(:get, "/subreddits/mine/moderator")["data"]["children"].map do |child|
    fail unless child["kind"] == "t5"
    child["data"]["display_name"].downcase
  end
  [
    # ["ion", "Developer"],
    # ["survivetheculling", "Developer"],
    ["vigorgame", "Developer"],
    ["insurgency", "Developer"],
    ["Battalion1944", "Developer"],
  ].each do |subreddit, developer_class|
    subreddit.downcase!
    next puts "!!! can't moderate #{subreddit} !!!" unless moderated.include? subreddit
    puts "sub: #{subreddit}"

    JSON.parse( begin
      NetHTTPUtils.request_data "https://www.reddit.com/r/#{subreddit}/comments.json", header: ["User-Agent", "ajsdjasdasd"]
    rescue NetHTTPUtils::Error => e
      raise unless [503, 504, 500].include? e.code
      sleep 60
      retry
    end )["data"]["children"].each do |comment|
      id = comment["data"]["link_id"][3..-1]
      commenter_flair = comment["data"]["author_flair_css_class"]
      puts "flair: #{commenter_flair}" if commenter_flair
      next unless developer_class == commenter_flair
      puts "https://reddit.com/r/#{subreddit}/comments/#{id}/#{comment["data"]["id"]} '#{commenter_flair}'"
      flairselector = BOT.json :post, "/api/flairselector", { link: comment["data"]["link_id"] }
      current_flair_class = flairselector["current"]["flair_css_class"]
      puts "existing https://reddit.com/#{id} #{current_flair_class.inspect}"
      next unless target = case current_flair_class
        when           nil  then "untaggeddev"
        when         "news" then "newsdev"
        when   "discussion" then "discussiondev"
        when        "media" then "mediadev"
        when     "feedback" then "feedbackdev"
        when     "question" then "questiondev"
        when          "bug" then "bugdev"
        when "announcement" then "announcementdev"
        when   "suggestion" then "suggestiondev"
        else puts "ignored https://reddit.com/#{id} #{current_flair_class.inspect}"
      end
      unless choice = flairselector["choices"].find{ |choice| choice["flair_css_class"] == target }
        next if reported.include? comment["data"]["link_id"]
        Google::Cloud::ErrorReporting.report RuntimeError.new("no '#{target}' link flair in /r/#{subreddit}").tap{ |_| _.set_backtrace caller }
        reported.push comment["data"]["link_id"]
        next
      end
      puts "assigning '#{target}' (#{choice}) flair to post https://reddit.com/#{id}"
      next if ENV["TEST"]
      _ = BOT.json :post,
        "/api/selectflair", {
          flair_template_id: choice["flair_template_id"],
          link: comment["data"]["link_id"],
        }
      fail _.inspect unless _ == {"json"=>{"errors"=>[]}}
    end

  end

  puts "END LOOP #{Time.now}"
  sleep 120
end
