require_relative File.join "..", "boilerplate"

BOT = RedditBot::Bot.new YAML.load(File.read "secrets.yaml"), ignore_captcha: true

SUBREDDIT = "codcompetitive"

loop do
  AWSStatus::touch
  catch :loop do

    text = " Live Streams\n\n" + [].tap do |list|

      throw :loop unless statuses = JSON.parse(
        DownloadWithRetry::download_with_retry("http://streamapi.majorleaguegaming.com/service/streams/all")[/\{.+\}/m]
      )["data"]["items"]
      begin
        JSON.parse DownloadWithRetry::download_with_retry(
          # DownloadWithRetry::download_with_retry("http://www.majorleaguegaming.com/api/channels/all.js?fields=id,name,slug,subtitle,game_id,stream_name,type,default_tab,is_hidden,chat_is_disabled,image_1_1,image_16_9,image_16_9_small,image_16_9_medium,image_background,url,embed_code,stream_featured,stream_sort_order,tags,tag_names,children,description,subscription_url,donate_url,donate_text,partner_embed")
          "http://www.majorleaguegaming.com/api/channels/all.js?fields=name,url,tags,stream_name"
        )
      rescue JSON::ParserError
        puts "JSON::ParserError"
        sleep 60
        retry
      end["data"]["items"].each do |item1|
        next unless item1["tags"].include? "COD Pro League"
        status = statuses.find{ |item2| item1["stream_name"] == item2["stream_name"] }
        next unless status && status["status"] > 0
        list << "* [](#mlg) [](##{
          ["?", "live", "replay"][status["status"]]
        }) [**#{
          item1["name"]
        }**](#{
          item1["url"]
        })"
      end

      require "cgi"
      JSON.parse(DownloadWithRetry::download_with_retry(
        "https://api.twitch.tv/kraken/streams?game=#{CGI::escape "Call of Duty: Black Ops III"}&access_token=#{File.read "twitch.token"}&channel=TyreeLegal,Phizzurp,TheFEARS,CMPLXX,Methodz,Blfire,Tylerfelo,Sender_cw,Diabolic_tv,MJChino,Clayster,Enable,Attach,Zoomaaa,John,ReplaysTV,SpacelyTV,ColeChanTV,SaintsRF,Proofy,Whea7s,ParasiteTV,Ricky,Nameless,Mirx1,Formal,Karma,Scumperjumper,Crimsix,Slacked,Octane,Aqua,Nagafen,Faccento,Jkap,Aches,Teepee,Sharp,Neslo,Goon_jar,TheoryCOD,SteveMochilaCanle,Silly,Merk,Studyy,K1lla93,Burns,Dedo,Swanny,Tommey,DylDaly,Gotaga,QwikerThanU,TCM_Moose,Themarkyb,Maven,MattMrX,CourageJD,Happyy97,Revan,PacmanianDevil,Loonnny,BriceyHD,TeeCM,Senderxz,Zoomaa"
      ))["streams"].each do |channel|
        list << "* [](#twitch) [](#live) [**#{
          channel["channel"]["display_name"]
        }**](#{
          channel["channel"]["url"]
        })"
      end

    end.join("  \n") + "\n"

    settings = BOT.json(:get, "/r/#{SUBREDDIT}/about/edit")["data"]
    # https://github.com/praw-dev/praw/blob/c45e5f6ca0c5cd9968b51301989eb82740f8dc85/praw/__init__.py#L1592
    settings.store "sr", settings.delete("subreddit_id")
    settings.store "lang", settings.delete("language")
    settings.store "link_type", settings.delete("content_options")
    settings.store "type", settings.delete("subreddit_type")
    settings.store "header-title", settings.delete("header_hover_text") || ""
    settings["domain"] ||= ""
    settings["submit_link_label"] ||= ""
    settings["submit_text_label"] ||= ""
    settings["allow_top"] = settings["allow_top"]
    settings.delete "default_set"

    prefix, postfix = settings["description"].split(/(?<=\n#####)\s*Live Streams.+?(?=\n#+)/im)
    unless postfix
      puts "!!! can't parse sidebar !!!"
      throw :loop
    end
    next puts "nothing to change" if prefix + text + postfix == settings["description"]

    settings["description"] = prefix + text + postfix
    _ = BOT.json :post, "/api/site_admin", settings.to_a
    fail _.inspect if _ != {"json"=>{"errors"=>[]}} && !(_["json"]["errors"].map(&:first) - ["BAD_CAPTCHA"]).empty?

  end
  sleep 60
end
