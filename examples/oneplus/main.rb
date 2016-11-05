require_relative "../boilerplate"

BOT = RedditBot::Bot.new YAML.load(File.read "secrets.yaml"), ignore_captcha: true
SUBREDDIT = "oneplus"

if Gem::Platform.local.os == "darwin"
  require_relative "../../../../dimensioner/get_dimensions"
else
  require_relative "#{Dir.home}/get_dimensions"
end

checked = []
loop do
  Hearthbeat.beat "u_oneplus_mod_r_oneplus", 310 unless Gem::Platform.local.os == "darwin"
  puts "LOOP #{Time.now}"

  BOT.json(:get, "/r/#{SUBREDDIT}/new")["data"]["children"].each do |post|
    id, url, title, subreddit = post["data"].values_at(*%w{ id url title subreddit })
    next if checked.include? id
    checked.push id
    redd_it = "https://redd.it/#{id}"
    next puts "skipped #{url} from #{redd_it}" if :skipped == _ = GetDimensions::get_dimensions(url)
    next puts "unable #{url} from #{redd_it}" unless _
    width, height, * = _
    result = ([1080, 1920] != resolution = [width, height])
    puts "#{result} #{id} [#{resolution}] #{title} #{url}"
    next if result

    ### delete
    BOT.json :post, "/api/remove",
      id: "t3_#{id}",
      spam: false
    ### modmail
    BOT.json :post, "/api/compose",
      subject: "possible screenshot detected",
      text: "please, investigate: #{redd_it}",
      to: "/r/#{SUBREDDIT}"

  end or puts "/r/#{SUBREDDIT} seems to be 403-ed"

  puts "END LOOP #{Time.now}"
  sleep 300
end
