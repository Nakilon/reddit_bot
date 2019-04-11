require_relative "../boilerplate"

require "nethttputils"
TWITTER_ACCESS_TOKEN = JSON.load(
  NetHTTPUtils.request_data "https://api.twitter.com/oauth2/token", :post,
    auth: File.read("twitter.token").split,
    form: {grant_type: :client_credentials}
)["access_token"]

SUBREDDIT = "RealTimeWW2"
BOT = RedditBot::Bot.new YAML.load(File.read "secrets.yaml"), subreddit: SUBREDDIT
TWITTER = "RealTimeWWII"

tweet2titleNtext = lambda do |tweet|
  pp tweet if ENV["TEST"]
  text = ""
  contains_media = false
  up = ->s{ s.split.map{ |w| "^#{w}" }.join " " }
  if tweet["extended_entities"] && !tweet["extended_entities"]["media"].empty?
    contains_media = true
    tweet["extended_entities"]["media"].each_with_index do |media, i|
      text.concat "* [Image #{i + 1}](#{media["media_url_https"]})\n\n"
    end
  end
  if !tweet["entities"]["urls"].empty?
    contains_media = true
    tweet["entities"]["urls"].each_with_index do |url, i|
      text.concat "* [Link #{i + 1}](#{url["expanded_url"]})\n\n"
    end
  end
  text.concat "^- #{
    up[tweet["user"]["name"]]
  } [^\\(@#{TWITTER}\\)](https://twitter.com/#{TWITTER}) ^| [#{
    up[Date.parse(tweet["created_at"]).strftime "%B %-d, %Y"]
  }](https://twitter.com/#{TWITTER}/status/#{tweet["id"]})"
  require "cgi"
  [CGI::unescapeHTML(tweet["full_text"]).sub(/( https:\/\/t\.co\/[0-9a-zA-Z]{10})*\z/, ""), text, contains_media]
end
[
  [905764294687633408,  true, "The Polish government & military high command is now evacuating Warsaw for Brest, 120 miles east: German armies are too close to the capital",   "* [Image 1](https://pbs.twimg.com/media/DJHq71BXYAA6KJ0.jpg)\n\n"                                                              "^- ^WW2 ^Tweets ^from ^1941 [^\\(@#{TWITTER}\\)](https://twitter.com/#{TWITTER}) ^| [^""September ^7, ^2017](https://twitter.com/#{TWITTER}/status/905764294687633408)"],
  [915534673471733760,  true, "In east Poland (now Soviet Ukraine) industry & farms to be collectivised, political parties banned, aristocrats & capitalists \"re-educated\".", "* [Image 1](https://pbs.twimg.com/media/DLSh2J9W4AACcOG.jpg)\n\n* [Image 2](https://pbs.twimg.com/media/DLSh4sKX0AEBaXq.jpg)\n\n^- ^WW2 ^Tweets ^from ^1941 [^\\(@#{TWITTER}\\)](https://twitter.com/#{TWITTER}) ^| [^"  "October ^4, ^2017](https://twitter.com/#{TWITTER}/status/915534673471733760)"],
  [915208866408824832,  true, "For 1st time, RAF planes dropping propaganda leaflets on Berlin itself, entitled \"Germans: these are your leaders!\"",                          "* [Image 1](https://pbs.twimg.com/media/DLN5jJ-XkAEUz9M.jpg)\n\n* [Link 1](https://www.psywar.org/product_1939EH158.php)\n\n"  "^- ^WW2 ^Tweets ^from ^1941 [^\\(@#{TWITTER}\\)](https://twitter.com/#{TWITTER}) ^| [^"  "October ^3, ^2017](https://twitter.com/#{TWITTER}/status/915208866408824832)"],
  [914577848891006978,  true, "\"In Poland, Russia pursued a cold policy of selfinterest. But clearly necessary for Russia… against Nazi menace.\"",                            "* [Link 1](https://www.youtube.com/watch?v=ygmP5A3n2JA)\n\n"                                                                   "^- ^WW2 ^Tweets ^from ^1941 [^\\(@#{TWITTER}\\)](https://twitter.com/#{TWITTER}) ^| [^"  "October ^1, ^2017](https://twitter.com/#{TWITTER}/status/914577848891006978)"],
  [926581977372942336, false, "Finland rejects Soviet demand to surrender land near Leningrad & give Red Navy base in Hanko; Soviets now claim Finns' manner \"warlike\".",                                                                                                                                     "^- ^WW2 ^Tweets ^from ^1941 [^\\(@#{TWITTER}\\)](https://twitter.com/#{TWITTER}) ^| [^" "November ^3, ^2017](https://twitter.com/#{TWITTER}/status/926581977372942336)"],
].each do |id, contains_media_, title_, text_|
  title, text, contains_media = tweet2titleNtext[ JSON.load NetHTTPUtils.request_data(
    "https://api.twitter.com/1.1/statuses/show.json",
    form: { id: id, tweet_mode: "extended" },
    header: { Authorization: "Bearer #{TWITTER_ACCESS_TOKEN}" },
  ) ]
  unless contains_media_ == contains_media
    puts "expected: #{contains_media_}"
    puts "got: #{contains_media}"
    abort "CONTAINS_MEDIA ERROR"
  end
  unless title_ == title
    puts "expected:\n#{title_.inspect}"
    puts "got:\n#{title.inspect}"
    abort "TITLE FORMATTING ERROR"
  end
  unless text_ == text
    puts "expected:\n#{text_.inspect}"
    puts "got:\n#{text.inspect}"
    abort "TEXT FORMATTING ERROR"
  end
  if ENV["TEST_POST"]
    pp BOT.json :post, "/api/submit", {
      sr: "RealTimeWW2_TEST",
      kind: "self",
      title: title,
      text: text,
    }.tap{ |h| h.merge!({ flair_id: BOT.json(:get, "/r/RealTimeWW2_TEST/api/link_flair").find{ |flair|
      flair["text"] == "Contains Media"
    }["id"] }) if contains_media }
  end
end
abort "OK" if ENV["TEST"]

loop do
  id = BOT.new_posts.find do |post|
    /\(https:\/\/twitter\.com\/#{TWITTER}\/status\/(\d{18,})\)/i =~ post["selftext"] and break $1
  end.to_i
  fail "no tweets found in subreddit" if id.zero? unless %w{ RealTimeWW2_TEST }.include? SUBREDDIT

  fail unless flair = BOT.json(:get, "/r/#{SUBREDDIT}/api/link_flair").find do |flair|
    flair["text"] == "Contains Media"
  end

  timeout = 1
  JSON.load( begin
    NetHTTPUtils.request_data(
      "https://api.twitter.com/1.1/statuses/user_timeline.json",
      form: { screen_name: TWITTER, count: 200, tweet_mode: "extended" },
      header: { Authorization: "Bearer #{TWITTER_ACCESS_TOKEN}" }
    ) do |res|
      next unless res.key? "x-rate-limit-remaining"
      remaining = res.fetch("x-rate-limit-remaining").to_i
      next if 100 < remaining
      t = (res.fetch("x-rate-limit-reset").to_i - Time.now.to_i + 1).fdiv remaining
      puts "sleep #{t}"
      sleep t
    end
  rescue NetHTTPUtils::Error => e
    fail if e.code != 503
    sleep timeout
    timeout *= 2
    retry
  end ).reverse_each do |tweet|
    next if tweet["id"] <= id
    # next unless tweet["id"] == 905724018996772865    # two media files
    title, text, contains_media = tweet2titleNtext[tweet]
    result = BOT.json :post, "/api/submit", {
      sr: SUBREDDIT,
      kind: "self",
      title: title,
      text: text,
    }.tap{ |h| h.merge!({ flair_id: flair["id"] }) if contains_media }
    pp result
    if result["json"]["errors"].empty?
      abort if ENV["ONCE"]
      next
    end
    fail unless result["json"]["errors"].map(&:first) == ["ALREADY_SUB"]
    puts "ALREADY_SUB error for #{tweet["id"]}"
  end

  puts "END LOOP #{Time.now}"
  sleep 300
end
