require_relative "../boilerplate"

BOT = RedditBot::Bot.new YAML.load(File.read "secrets.yaml"), ignore_captcha: true

require_relative "../../../../dimensioner/get_dimensions"

SUBREDDIT = "oneplus"
# FLAIR_CLASS = "redflair"

checked = []
loop do
  AWSStatus::touch
  puts "LOOP #{Time.now}"

  BOT.json(:get, "/r/#{SUBREDDIT}/new")["data"]["children"].each do |item|
    id, url, title, subreddit = item["data"].values_at(*%w{ id url title subreddit })
    next if checked.include? id # WTF?
    checked << id
    redd_it = "https://redd.it/#{id}"
    next puts "skipped #{url} from #{redd_it}" if :skipped == _ = GetDimensions::get_dimensions(url)
    next puts "unable #{url} from #{redd_it}" unless _
    width, height, * = _
    result = ([1080, 1920] != resolution = [width, height])
    puts "#{result} #{id} [#{resolution}] #{title} #{url}"
    next if result

    ### flair
    # {"json"=>{"errors"=>[]}} == _ = BOT.json(:post,
    #   "/api/selectflair",
    #     flair_template_id: BOT.json(:post,
    #       "/api/flairselector",
    #         link: "t3_#{id}",
    #     )["choices"].find{ |i| i["flair_css_class"] == FLAIR_CLASS }["flair_template_id"],
    #     link: "t3_#{id}",
    # ) or fail _.inspect
    ### report
    # BOT.report "1080x1920", "t3_#{id}"

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
