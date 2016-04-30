require_relative "../boilerplate"

BOT = RedditBot::Bot.new YAML.load(File.read "secrets.yaml"), ignore_captcha: true#, subreddit: SUBREDDIT
SUBREDDIT = "wallpaper"

if ENV["LOGNAME"] == "nakilon"
  require_relative "../../../../dimensioner/get_dimensions"
else
  require_relative File.join Dir.home, "dimensioner/get_dimensions"
end

checked = []
loop do
  AWSStatus::touch
  puts "LOOP #{Time.now}"

  # _ = DownloadWithRetry::download_with_retry("https://www.reddit.com/r/#{SUBREDDIT}.json?sort=new&restrict_sr=on&t=hour") \
  BOT.json(:get, "/r/#{SUBREDDIT}/new")["data"]["children"].each do |post|
    id, url, title, subreddit = post["data"].values_at(*%w{ id url title subreddit })
    next if checked.include? id
    checked.push id
    next puts "skipped #{url} from http://redd.it/#{id}" if :skipped == _ = GetDimensions::get_dimensions(url)
    next puts "unable #{url} from http://redd.it/#{id}" unless _
    width, height, best_direct_url, *all_direct_urls = _

    resolution = "#{width}x#{height}"
    result = title[/\s*\[?#{width}\s*[*x×]\s*#{height}\]?\s*/i]
    puts "#{!!result} #{id} [#{resolution}] #{title} #{url}"
    BOT.report "true resolution is #{resolution}", "t3_#{id}" unless result
  end

  puts "END LOOP #{Time.now}"
  sleep 60
end
