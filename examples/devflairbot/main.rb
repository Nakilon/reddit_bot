require_relative "../boilerplate"

BOT = RedditBot::Bot.new YAML.load(File.read "secrets.yaml"), ignore_captcha: true#, subreddit: SUBREDDIT


loop do
  AWSStatus::touch
  puts "LOOP #{Time.now}"

  [
    ["ion", "Developer"],
    ["survivetheculling", "Developer"],
  ].each do |subreddit, developer_class|
    puts subreddit

    JSON.parse(
      DownloadWithRetry::download_with_retry("https://www.reddit.com/r/#{subreddit}/comments.json")
    )["data"]["children"].each do |comment|
      id = comment["data"]["link_id"][3..-1]
      commenter_flair = comment["data"]["author_flair_css_class"]
      puts commenter_flair if commenter_flair
      next 'puts "skip"' unless developer_class == commenter_flair
      puts "https://reddit.com/r/#{subreddit}/comments/#{id}/#{comment["data"]["id"]} '#{commenter_flair}'"
      flairselector = BOT.json :post, "/api/flairselector", { link: comment["data"]["link_id"] }
      existing_flair_class = flairselector["current"]["flair_css_class"]
      puts "https://reddit.com/#{id} '#{existing_flair_class}'"
      next unless target = case existing_flair_class
        when           nil  then "untaggeddev"
        when         "news" then "newsdev"
        when   "discussion" then "discussiondev"
        when        "media" then "mediadev"
        when     "feedback" then "feedbackdev"
        when     "question" then "questiondev"
        when          "bug" then "bugdev"
        when "announcement" then "announcementdev"
        when   "suggestion" then "suggestiondev"
        else puts "ignored https://reddit.com/#{id} '#{existing_flair_class}'"
      end
      choice = flairselector["choices"].find{ |choice| choice["flair_css_class"] == target }
      puts "assigning '#{target}' (#{choice}) flair to post https://reddit.com/#{id}"
      _ = BOT.json :post,
        "/api/selectflair", {
          flair_template_id: choice["flair_template_id"],
          link: comment["data"]["link_id"],
        }
      fail _.inspect unless _ == {"json"=>{"errors"=>[]}}
    end

  end

  puts "END LOOP #{Time.now}"
  sleep 60
end
