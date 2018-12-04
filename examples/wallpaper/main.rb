require_relative "../boilerplate"

BOT = RedditBot::Bot.new YAML.load File.read "secrets.yaml"
SUBREDDIT = "wallpaper"

require "directlink"

checked = []
loop do
  puts "LOOP #{Time.now}"

  BOT.json(:get, "/r/#{SUBREDDIT}/new")["data"]["children"].each do |post|
    id, url, title, subreddit = post["data"].values_at(*%w{ id url title subreddit })
    next if checked.include? id
    checked.push id
    t = DirectLink url
    (t.is_a?(Array) ? t : [t]).each do |s|
      resolution = "#{s.width}x#{s.height}"
      result = title[/\s*\[?#{s.width}\s*[*x×]\s*#{s.height}\]?\s*/i]
      puts "#{!!result} #{id} [#{resolution}] #{title} #{s.url}"
      BOT.report "true resolution is #{resolution}", "t3_#{id}" unless result
    end
  end

  puts "END LOOP #{Time.now}"
  sleep 60
end
