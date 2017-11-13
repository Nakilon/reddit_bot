### THIS WAS MY THE VERY FIRST REDDIT BOT


# if Gem::Platform.local.os == "darwin"
#   require_relative "../../../tcpsm/lib/tcp_socket_measurer"
# else
#   require_relative "#{Dir.home}/tcp_socket_measurer"
# end

# %w{
#   198.41.208.137
#   198.41.208.138
#   198.41.208.139
#   198.41.208.140
#   198.41.208.141
#   198.41.208.142
#   198.41.208.143
#   198.41.209.136
#   198.41.209.137
#   198.41.209.138
#   198.41.209.139
#   198.41.209.140
#   198.41.209.141
#   198.41.209.142
#   198.41.209.143

#   151.101.33.140
#   151.101.32.193
# }.each do |ip|
#   TCPSocketMeasurer.known_hosts[ip] = "www.reddit.com"
# end
# Thread.new do
#   loop do
#     TCPSocketMeasurer.report
#     puts "next report is in an hour"
#     sleep 3600
#   end
# end


require_relative "../get_dimensions"


require "../boilerplate"
BOT = RedditBot::Bot.new YAML.load File.read "secrets.yaml"

INCLUDE = %w{
    user/kjoneslol/m/sfwpornnetwork

    r/woahdude

    r/highres
    r/wallpapers
    r/wallpaper
    r/WQHD_Wallpaper

    r/pic
}
EXCLUDE = %w{ foodporn powerwashingporn }

checked = []
loop do
  puts "LOOP #{Time.now}"

  require "nokogiri"
  Nokogiri::XML(NetHTTPUtils.request_data ENV["FEEDPCBR_URL"]).remove_namespaces!.xpath("feed/entry").each do |entry|
    pp entry
    break
    update_item( {
      author:    entry.at_xpath("author/name").text,
      category:  entry.at_xpath("category")["term"],
      id:        entry.at_xpath("id").text,
      alternate: entry.at_xpath("link[@rel='alternate']")["href"],
      via:       entry.at_xpath("link[@rel='via']")["href"],
      title:     entry.at_xpath("title").text,
      updated:   Time.parse(entry.at_xpath("updated").text),
      published: Time.parse(entry.at_xpath("published").text).to_i,
      score:     entry.at_xpath("summary").text.to_i,
    }, store)
  end

  INCLUDE.each do |sortasub|
    BOT.new_posts(sortasub).take(100).each do |child|
      next if child["is_self"]
      next if EXCLUDE.include? child["subreddit"].downcase
      pp child
      abort
    end
  end
abort

  [].each do |where|

    _ = BOT.json(:get, "/#{where}/new")["data"]["children"].each do |post|
      id, url, title, subreddit = post["data"].values_at(*%w{ id url title subreddit })
      next puts "skipped /r/FoodPorn" if subreddit.downcase == "foodporn"
# id, url, title, subreddit = "39ywvu", "http://i.imgur.com/WGdRPmT.jpg", "I don't know how fireworks have anything to do with genocide, but this manufacturer clearly begs to differ", "wtf"
      next if checked.include? id
      checked << id
# id = "36y3w1"
# url = "http://i.imgur.com/c6uGJV0.jpg"
      # unless (url = item["data"]["url"])[%r{//[^/]*imgur\.com/}]
      # next if Gem::Platform.local.os == "darwin" # prevent concurrent posting
      next puts "skipped #{url} from http://redd.it/#{id}" if :skipped == _ = GetDimensions::get_dimensions(url)
      next puts "unable #{url} from http://redd.it/#{id}" unless _
      width, height, best_direct_url, *all_direct_urls = _
      unless 5000000 <= width * height
        # puts " -- that is too small"
        next
      end
      # next if Gem::Platform.local.os == "darwin" # prevent concurrent posting
      # puts "https://www.reddit.com/r/LargeImages/search.json?q=url%3A#{CGI.escape url}&restrict_sr=on"
      resolution = "[#{width}x#{height}]"
      require "cgi"
      next puts "already submitted #{resolution} #{id}: '#{url}'" unless
        Gem::Platform.local.os == "darwin" ||
        (JSON.parse NetHTTPUtils.request_data "https://www.reddit.com/r/LargeImages/search.json?q=url%3A#{CGI.escape url}&restrict_sr=on", header: ["User-Agent", "ajsdjasdasd"])["data"]["children"].empty?
      puts "#{resolution} got from #{id}: #{url}"
      # next if Gem::Platform.local.os == "darwin" # prevent concurrent posting
      title = "#{resolution}#{
        " [#{all_direct_urls.size} images]" if all_direct_urls.size > 1
      } #{
        title.sub(/\s*\[?#{width}\s*[*x×]\s*#{height}\]?\s*/i, " ").
              gsub(/\s+/, " ").strip.
              sub(/(.{#{100 - subreddit.size}}).+/, '\1...')
      } /r/#{subreddit}".
        gsub(/\s+\(\s+\)\s+/, " ")
      if Gem::Platform.local.os == "darwin"
        puts title
      else
        result = BOT.json :post,
          "/api/submit",
          {
            kind: "link",
            url: url,
            sr: "LargeImages",
            title: title,
          }
        next unless result["json"]["errors"].empty?
        puts result["json"]["data"]["url"]
      end
        # {"json"=>
        #   {"errors"=>[],
        #    "data"=>
        #     {"url"=>
        #       "https://www.reddit.com/r/LargeImages/comments/3a9rel/2594x1724_overlooking_wildhorse_lake_from_near/",
        #      "id"=>"3a9rel",
        #      "name"=>"t3_3a9rel"}}}
      line1 = "[Original thread](https://www.reddit.com#{post["data"]["permalink"]}) by /u/#{post["data"]["author"]}"
      line2 = "Direct link#{" (the largest image)" if all_direct_urls.size > 1}: #{best_direct_url}"
      line3 = [
        "Direct links to all other images in album:",
        all_direct_urls - [best_direct_url]
      ] if all_direct_urls.size > 1
      text = [line1, line2, line3].compact.join("  \n")
      if Gem::Platform.local.os == "darwin"
        puts text
      else
        result = BOT.leave_a_comment "#{result["json"]["data"]["name"]}", text.sub(/(?<=.{9000}).+/m, "...")
        unless result["json"]["errors"].empty?
          p result
          fail "failed to leave comment"
        end
      end
    end
  end

  puts "END LOOP #{Time.now}"
  sleep 300
end
