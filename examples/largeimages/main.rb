### THIS WAS MY THE VERY FIRST REDDIT BOT


require "gcplogger"
logger = GCPLogger.logger "largeimagesbot"

fail "no ENV['ERROR_REPORTING_KEYFILE'] specified" unless ENV["ERROR_REPORTING_KEYFILE"]
require "google/cloud/error_reporting"
Google::Cloud::ErrorReporting.configure do |config|
  config.project_id = JSON.load(File.read ENV["ERROR_REPORTING_KEYFILE"])["project_id"]
end


require "directlink"

require "nokogiri"

require "../boilerplate"
BOT = RedditBot::Bot.new YAML.load_file "secrets.yaml"

INCLUDE = %w{
    user/kjoneslol/m/sfwpornnetwork

    r/woahdude
    r/pic

    r/highres
    r/wallpapers
    r/wallpaper
    r/WQHD_Wallpaper

    r/oldmaps
    r/telephotolandscapes
}
EXCLUDE = %w{ foodporn powerwashingporn }

checked = []

search_url = lambda do |url|
  JSON.load( begin
    NetHTTPUtils.request_data "https://www.reddit.com/r/largeimages/search.json", form: {q: "url:#{url}", restrict_sr: "on"}, header: ["User-Agent", "ajsdjasdasd"]
  rescue NetHTTPUtils::Error => e
    raise unless [500, 503].include? e.code
    sleep 60
    retry
  end )["data"]["children"]
end
fail unless 1 == search_url["https://i.imgur.com/9JTxtjW.jpg"].size

loop do
  begin
    logger.info "LOOP #{Time.now}"
  rescue => e
    puts "oops"
    Google::Cloud::ErrorReporting.report e
    sleep 5
    raise
  end

  [ [:source_ultireddit, 10000000, ( Nokogiri::XML( begin
        NetHTTPUtils.request_data ENV["FEEDPCBR_URL"]
      rescue NetHTTPUtils::Error => e
        raise unless [502, 504].include? e.code
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
    [:source_reddit, 30000000, ( INCLUDE.flat_map do |sortasub|
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
      author.downcase!
      next if checked.include? id
      checked << id
      # next if Gem::Platform.local.os == "darwin" # prevent concurrent posting
      logger.debug "image url for #{id}: #{url}"
      next logger.warn "skipped a post by /u/sjhill"          if author == "sjhill"          # opt-out
      next logger.warn "skipped a post by /u/redisforever"    if author == "redisforever"    # opt-out
      next logger.warn "skipped a post by /u/bekalaki"        if author == "bekalaki"        # 9 ways to divide a karmawhore
      next logger.warn "skipped a post by /u/cherryblackeyes" if author == "cherryblackeyes" # he's not nice
      next logger.warn "skipped gifv" if URI(url).host.split(?.) == %w{ v redd it }

      t = begin
        DirectLink url, 60
      rescue SocketError,
             Net::OpenTimeout,
             Errno::ECONNRESET,
             NetHTTPUtils::Error,
             FastImage::UnknownImageType,
             FastImage::ImageFetchFailure,
             DirectLink::ErrorNotFound,
             DirectLink::ErrorBadLink => e
        next logger.error "skipped (#{e}) #{url} from http://redd.it/#{id}"
      end
      logger.info "DirectLink: #{t.inspect}"
      tt = t.is_a?(Array) ? t : [t]
      next logger.error "probably crosspost of a self post: http://redd.it/#{id}" if tt.empty?
      unless min_resolution <= tt.first.width * tt.first.height
        next logger.debug "skipped low resolution #{source}"
      end
      # puts "https://www.reddit.com/r/LargeImages/search.json?q=url%3A#{CGI.escape url}&restrict_sr=on"
      resolution = "[#{tt.first.width}x#{tt.first.height}]"
      next logger.warn "already submitted #{resolution} #{id}: '#{url}'" unless
        Gem::Platform.local.os == "darwin" || search_url[url].empty?
      logger.warn "resolution #{resolution} got from #{id}: #{url}"
      title = "#{resolution}#{
        " [#{tt.size} images]" if tt.size > 1
      } #{
        title.sub(/\s*\[?#{tt.first.width}\s*[*x×]\s*#{tt.first.height}\]?\s*/i, " ").
              sub("[OC]", " ").gsub(/\s+/, " ").strip
      } /r/#{subreddit}".gsub(/\s+\(\s+\)\s+/, " ").sub(/(?<=.{297}).+/, "...")
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
      line2 = "Direct link#{" (the largest image)" if tt.size > 1}: #{tt.first.url}"
      line3 = [
        "Direct links to all other images in album:",
        tt.map(&:url) - [tt.first.url]
      ] if tt.size > 1
      text = [line1, line2, line3].compact.join("  \n")
      logger.info "new comment: #{text.inspect}"
      unless Gem::Platform.local.os == "darwin"
        result = BOT.leave_a_comment "#{result["json"]["data"]["name"]}", text.sub(/(?<=.{9000}).+/m, "...")
        unless result["json"]["errors"].empty?
          logger.error result.inspect
          fail "failed to leave comment"
        end
      end

      abort if Gem::Platform.local.os == "darwin"
    end
  end

  logger.info "END LOOP #{Time.now}"
  sleep 300
end
