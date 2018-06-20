require "json"
require "nethttputils"

TWITTER_ACCESS_TOKEN = JSON.load(
  NetHTTPUtils.request_data "https://api.twitter.com/oauth2/token", :post,
    auth: File.read("twitter.token").split,
    form: {grant_type: :client_credentials}
)["access_token"]

Tweet2titleNtext = lambda do |tweet|
  pp tweet if ENV["TEST"]
  text = ""
  contains_media = false
  up = ->s{ s.split.map{ |w| "^#{w}" }.join " " }

  tweet_to_get_media_from = tweet["retweeted_status"] || tweet
  if tweet_to_get_media_from["extended_entities"] && !tweet_to_get_media_from["extended_entities"]["media"].empty?
    contains_media = true
    tweet_to_get_media_from["extended_entities"]["media"].each_with_index do |media, i|
      text.concat "* [Image #{i + 1}](#{media["media_url_https"]})\n\n"
    end
  end
  if !tweet_to_get_media_from["entities"]["urls"].empty?
    contains_media = true
    tweet_to_get_media_from["entities"]["urls"].each_with_index do |url, i|
      text.concat "* [Link #{i + 1}](#{url["expanded_url"]})\n\n"
    end
  end

  require "date"
  text.concat "^- #{
    up[tweet["user"]["name"]]
  } [^\\(@#{TWITTER}\\)](https://twitter.com/#{TWITTER}) ^| [#{
    up[Date.parse(tweet["created_at"]).strftime "%B %-d, %Y"]
  }](https://twitter.com/#{TWITTER}/status/#{tweet["id"]})"
  require "cgi"
  # [CGI::unescapeHTML(tweet["full_text"]).sub(/( https:\/\/t\.co\/[0-9a-zA-Z]{10})*\z/, ""), text, contains_media]
  [CGI::unescapeHTML(tweet["retweeted_status"] ? "RT: #{tweet["retweeted_status"]["full_text"]}" : tweet["full_text"]).sub(/(\s+https:\/\/t\.co\/[0-9a-zA-Z]{10})*\z/, ""), text, contains_media]
end
[
  [905764294687633408,   true, "The Polish government & military high command is now evacuating Warsaw for Brest, 120 miles east: German armies are too close to the capital",   "* [Image 1](https://pbs.twimg.com/media/DJHq71BXYAA6KJ0.jpg)\n\n"                                                              "^- ^WW2 ^Tweets ^from ^1940 [^\\(@#{TWITTER}\\)](https://twitter.com/#{TWITTER}) ^| [^""September ^7, ^2017](https://twitter.com/#{TWITTER}/status/905764294687633408)"],
  [915534673471733760,   true, "In east Poland (now Soviet Ukraine) industry & farms to be collectivised, political parties banned, aristocrats & capitalists \"re-educated\".", "* [Image 1](https://pbs.twimg.com/media/DLSh2J9W4AACcOG.jpg)\n\n* [Image 2](https://pbs.twimg.com/media/DLSh4sKX0AEBaXq.jpg)\n\n^- ^WW2 ^Tweets ^from ^1940 [^\\(@#{TWITTER}\\)](https://twitter.com/#{TWITTER}) ^| [^"  "October ^4, ^2017](https://twitter.com/#{TWITTER}/status/915534673471733760)"],
  [915208866408824832,   true, "For 1st time, RAF planes dropping propaganda leaflets on Berlin itself, entitled \"Germans: these are your leaders!\"",                          "* [Image 1](https://pbs.twimg.com/media/DLN5jJ-XkAEUz9M.jpg)\n\n* [Link 1](https://www.psywar.org/product_1939EH158.php)\n\n"  "^- ^WW2 ^Tweets ^from ^1940 [^\\(@#{TWITTER}\\)](https://twitter.com/#{TWITTER}) ^| [^"  "October ^3, ^2017](https://twitter.com/#{TWITTER}/status/915208866408824832)"],
  [914577848891006978,   true, "\"In Poland, Russia pursued a cold policy of selfinterest. But clearly necessary for Russia… against Nazi menace.\"",                            "* [Link 1](https://www.youtube.com/watch?v=ygmP5A3n2JA)\n\n"                                                                   "^- ^WW2 ^Tweets ^from ^1940 [^\\(@#{TWITTER}\\)](https://twitter.com/#{TWITTER}) ^| [^"  "October ^1, ^2017](https://twitter.com/#{TWITTER}/status/914577848891006978)"],
  [926581977372942336,  false, "Finland rejects Soviet demand to surrender land near Leningrad & give Red Navy base in Hanko; Soviets now claim Finns' manner \"warlike\".",                                                                                                                                     "^- ^WW2 ^Tweets ^from ^1940 [^\\(@#{TWITTER}\\)](https://twitter.com/#{TWITTER}) ^| [^" "November ^3, ^2017](https://twitter.com/#{TWITTER}/status/926581977372942336)"],
  [1007650044441329664,  true, "RT: SOLD OUT | Tonight’s @Johnny_Marr signing at Rough Trade East is now completely sold out! Catch you in a bit. ‘Call The Comet’ is out now:", "* [Image 1](https://pbs.twimg.com/media/DfvdN1_WsAE_a3r.jpg)\n\n* [Link 1](https://roughtrade.com/gb/music/johnny-marr-call-the-comet)\n\n^- ^Johnny ^Marr [^\\(@#{TWITTER}\\)](https://twitter.com/#{TWITTER}) ^| [^June ^15, ^2018](https://twitter.com/#{TWITTER}/status/1007650044441329664)"],
  [1007155648612581376,  true, "Tomorrow. #CallTheComet",                                                                                                                        "* [Image 1](https://pbs.twimg.com/ext_tw_video_thumb/1007155601913204736/pu/img/IREVPkgUVHoQHfBB.jpg)\n\n"                               "^- ^Johnny ^Marr [^\\(@#{TWITTER}\\)](https://twitter.com/#{TWITTER}) ^| [^June ^14, ^2018](https://twitter.com/#{TWITTER}/status/1007155648612581376)"],
].each do |id, contains_media_, title_, text_|
  title, text, contains_media = Tweet2titleNtext[ JSON.load NetHTTPUtils.request_data(
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
      sr: "#{SUBREDDIT}_TEST",
      kind: "self",
      title: title,
      text: text,
    }.tap{ |h| h.merge!({ flair_id: BOT.json(:get, "/r/#{SUBREDDIT}_TEST/api/link_flair").find{ |flair|
      flair["text"] == "Contains Media"
    }["id"] }) if contains_media }
  end
end
abort "OK" if ENV["TEST"]
