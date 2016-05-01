require_relative "../boilerplate"

BOT = RedditBot::Bot.new YAML.load(File.read "secrets.yaml"), ignore_captcha: true#, subreddit: SUBREDDIT
SUBREDDIT = "ion"

DEVELOPER_CLASS = "Developer"


loop do
  AWSStatus::touch
  puts "LOOP #{Time.now}"

  JSON.parse(
    DownloadWithRetry::download_with_retry("https://www.reddit.com/r/#{SUBREDDIT}/comments.json")
  )["data"]["children"].each do |comment|
    id = comment["data"]["link_id"][3..-1]
    next 'puts "skip"' unless DEVELOPER_CLASS == commenter_flair = comment["data"]["author_flair_css_class"]
    puts "https://reddit.com/r/#{SUBREDDIT}/comments/#{id}/#{comment["data"]["id"]} '#{commenter_flair}'"
    flairselector = BOT.json :post, "/api/flairselector", { link: comment["data"]["link_id"] }
    existing_flair_class = flairselector["current"]["flair_css_class"]
    puts "https://reddit.com/#{id} '#{existing_flair_class}'"
    next unless target = case existing_flair_class
      when         nil  then "untaggeddev"
      when       "news" then "newsdev"
      when "discussion" then "discussiondev"
      else puts "ignored https://reddit.com/#{id} '#{existing_flair_class}'"
    end
    puts "assigning '#{target}' flair to post https://reddit.com/#{id}"
    choice = flairselector["choices"].find{ |choice| choice["flair_css_class"] == target }
    _ = BOT.json :post,
      "/api/selectflair", {
        flair_template_id: choice["flair_template_id"],
        link: comment["data"]["link_id"],
      }
    fail _.inspect unless _ == {"json"=>{"errors"=>[]}}
  end

  sleep 60
end
