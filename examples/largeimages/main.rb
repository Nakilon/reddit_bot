### THIS WAS MY THE VERY FIRST REDDIT BOT


require "gcplogger"
logger = GCPLogger.logger "largeimagesbot"

fail("no ENV['ERROR_REPORTING_KEYFILE'] specified") unless ENV["ERROR_REPORTING_KEYFILE"]
require "google/cloud/error_reporting"
Google::Cloud::ErrorReporting.configure do |config|
  config.project_id = (JSON.load File.read ENV["ERROR_REPORTING_KEYFILE"])["project_id"]
end


require_relative "../get_dimensions"
Imgur.logger = logger

require "nokogiri"

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

    r/oldmaps
}
EXCLUDE = %w{ foodporn powerwashingporn }

checked = []

loop do
  begin
    logger.warn "LOOP #{Time.now}"
  rescue => e
    puts "oops"
    Google::Cloud::ErrorReporting.report e
    sleep 5
    raise
  end

  [ [:source_ultireddit, 10000000, ( Nokogiri::XML( begin
        NetHTTPUtils.request_data ENV["FEEDPCBR_URL"]
      rescue NetHTTPUtils::Error => e
        raise unless 504 == e.code
        sleep 60
        retry
      end ).remove_namespaces!.xpath("feed/entry").map do |entry|
    [
      entry.at_xpath("id").text,
      entry.at_xpath("link[@rel='via']")["href"],
      entry.at_xpath("title").text,
      entry.at_xpath("category")["term"],
      entry.at_xpath("author/name").text,
      entry.at_xpath("link[@rel='alternate']")["href"],
    ]
  end ) ],
    [:source_reddit, 20000000, ( INCLUDE.flat_map do |sortasub|
    BOT.new_posts(sortasub).take(100).map do |child|
      next if child["is_self"]
      next if EXCLUDE.include? child["subreddit"].downcase
      child.values_at(
        *%w{ id url title subreddit author permalink }
      ).tap{ |_| _.last.prepend "https://www.reddit.com" }
    end.compact
  end ) ],
  ].each do |source, min_resolution, entries|
    logger.warn "#{source}.size: #{entries.size}"
    entries.each do |id, url, title, subreddit, author, permalink|
      next if checked.include? id
      checked << id
      # next if Gem::Platform.local.os == "darwin" # prevent concurrent posting
      logger.debug "image url for #{id}: #{url}"
      next logger.warn "skipped a post by /u/sjhill" if author == "sjhill"

      next logger.warn "skipped (GetDimensions :skipped) #{url} from http://redd.it/#{id}" if :skipped == _ = begin
        GetDimensions::get_dimensions CGI.unescape_html url
      rescue GetDimensions::Error404
        next logger.warn "skipped (GetDimensions::Error404) #{url} from http://redd.it/#{id}"
      rescue GetDimensions::ErrorUnknown
        next logger.warn "skipped (GetDimensions::ErrorUnknown) #{url} from http://redd.it/#{id}"
      end
      fail "unable #{url} from http://redd.it/#{id}" unless _
      width, height, best_direct_url, *all_direct_urls = _
      logger.info "GetDimensions: %p" % [[width, height, best_direct_url, all_direct_urls.size]]
      unless min_resolution <= width * height
        next logger.warn "skipped low resolution #{source}"
      end
      # next if Gem::Platform.local.os == "darwin" # prevent concurrent posting
      # puts "https://www.reddit.com/r/LargeImages/search.json?q=url%3A#{CGI.escape url}&restrict_sr=on"
      resolution = "[#{width}x#{height}]"
      # require "cgi"
      next logger.warn "already submitted #{resolution} #{id}: '#{url}'" unless
        Gem::Platform.local.os == "darwin" ||
        (JSON.parse NetHTTPUtils.request_data "https://www.reddit.com/r/LargeImages/search.json?q=url%3A#{CGI.escape url}&restrict_sr=on", header: ["User-Agent", "ajsdjasdasd"])["data"]["children"].empty?
      logger.warn "resolution #{resolution} got from #{id}: #{url}"
      # next if Gem::Platform.local.os == "darwin" # prevent concurrent posting
      title = "#{resolution}#{
        " [#{all_direct_urls.size} images]" if all_direct_urls.size > 1
      } #{
        title.sub(/\s*\[?#{width}\s*[*x×]\s*#{height}\]?\s*/i, " ").
              sub("[OC]", " ").gsub(/\s+/, " ").strip.
              gsub(/(?<=.{190 - subreddit.size}).+/, "...")
      } /r/#{subreddit}".
        gsub(/\s+\(\s+\)\s+/, " ")
      logger.warn "new post #{source}: #{url} #{title.inspect}"
      unless Gem::Platform.local.os == "darwin"
        result = BOT.json :post,
          "/api/submit",
          {
            kind: "link",
            url: url,
            sr: "LargeImages",
            title: title,
          }
        next unless result["json"]["errors"].empty?
        logger.info "post url: #{result["json"]["data"]["url"]}"
      end
        # {"json"=>
        #   {"errors"=>[],
        #    "data"=>
        #     {"url"=>
        #       "https://www.reddit.com/r/LargeImages/comments/3a9rel/2594x1724_overlooking_wildhorse_lake_from_near/",
        #      "id"=>"3a9rel",
        #      "name"=>"t3_3a9rel"}}}
      line1 = "[Original thread](#{permalink}) by /u/#{author}"
      line2 = "Direct link#{" (the largest image)" if all_direct_urls.size > 1}: #{best_direct_url}"
      line3 = [
        "Direct links to all other images in album:",
        all_direct_urls - [best_direct_url]
      ] if all_direct_urls.size > 1
      text = [line1, line2, line3].compact.join("  \n")
      logger.info "new comment: #{text.inspect}"
      unless Gem::Platform.local.os == "darwin"
        result = BOT.leave_a_comment "#{result["json"]["data"]["name"]}", text.sub(/(?<=.{9000}).+/m, "...")
        unless result["json"]["errors"].empty?
          logger.error result.inspect
          fail "failed to leave comment"
        end
      end

      abort if ENV["TEST"]
    end
  end

  logger.warn "END LOOP #{Time.now}"
  sleep 300
end
