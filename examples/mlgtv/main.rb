require_relative File.join "../boilerplate"

BOT = RedditBot::Bot.new YAML.load(File.read "secrets.yaml"), ignore_captcha: true

SUBREDDIT = "codcompetitive"

loop do
  Hearthbeat.beat "u_OpTicNaDeBoT_r_CoDCompetitive", 70 unless Gem::Platform.local.os == "darwin"
  catch :loop do

    text = " Live Streams\n\n" + [].tap do |list|

      throw :loop unless statuses = JSON.parse(
        NetHTTPUtils.request_data("http://streamapi.majorleaguegaming.com/service/streams/all")[/\{.+\}/m]
      )["data"]["items"]
      begin
        JSON.parse NetHTTPUtils.request_data "http://www.majorleaguegaming.com/api/channels/all.js?fields=name,url,tags,stream_name"
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
      # to update access_token:
      # 0. see 'client_id' here https://www.twitch.tv/settings/connections and 'client_secret' from local ./readme file
      # 1. get 'code' by visiting in browser: https://api.twitch.tv/kraken/oauth2/authorize?response_type=code&client_id=*******&redirect_uri=http://www.example.com/unused/redirect/uri&scope=channel_read channel_feed_read
      # 2. NetHTTPUtils.request_data("https://api.twitch.tv/kraken/oauth2/token", :post, form: {client_id: "*******", client_secret: "*****", grant_type: "authorization_code", redirect_uri: "http://www.example.com/unused/redirect/uri", code: "*******"})
      [
        "Call of Duty: Infinite Warfare",
        "Call of Duty: Modern Warfare Remastered",
        "Call of Duty 4: Modern Warfare",
      ].each do |game|
        (begin
          JSON.parse NetHTTPUtils.request_data "https://api.twitch.tv/kraken/streams?game=#{CGI::escape game}&access_token=#{File.read("twitch.token").strip}&client_id=#{File.read("client.id").strip}&channel=Ricky,ACHES,Lacefield,Clayster,Enable,Zoomaa,Attach,TheFEARS,PHiZZURP,MiRx1,SaintsRF,StuDyy,SpaceLyTV,NAMELESS,Scumperjumper,FORMAL,Crimsix,Karma,Loony,Slacked,Octane,MJChino,Diabolic_TV,ImTheIvy,Senderxz,Jkap,John,SlasheRAL,Apathy,ColtHavok,MikeSwarley,ParasiteTV,TyreeLegal,Silly,Blfire,methodz,TwiZzyTV,Mochila,Remy,Xotic16,AquA,Faccento,Nagafen,Tylerfelo,TheoryCoD,ColeChanTV,happyy97,goonjar,Burns,Dedo,Neslo,TeeCM,K1lla93,NeLsoNNaTeR,ProoFy,Whea7s,MBoZe,Merk,Nadeshot,ReeP,Sharp,TeePee,Braaain2015,Nolsonn,QwiKeRTHaNu,Zedenyer1,Jurd,Tommey,Swanny,MadCatEU,Rated_EU1,BsportJoshh,Sy_Vortex,TheMarkyB,Peatie95,urbandm,TreiZer0,iDqvee,Tojor,MethodZ_TV,Gotaga,WailersWL,TCM_Moose,RampageSkrapz,Reedy,fighta71,Swiftazor,BacabecNZ,Zeuss_Gaming,Hopeyy,GuydraCOD,mattmrx,Maven,CouRageJD,Revan,BriceyHD,Benson,PHILWHI7"
        rescue JSON::ParserError
          puts "JSON::ParserError"
          sleep 60
          retry
        end["streams"] || []).each do |channel|
          list << "* [](#twitch) [](#live) [**#{
            channel["channel"]["display_name"]
          }**](#{
            channel["channel"]["url"]
          })"
        end
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

    puts "updating sidebar..."
    settings["description"] = prefix + text + postfix
    _ = BOT.json :post, "/api/site_admin", settings.to_a
    fail _.inspect if _ != {"json"=>{"errors"=>[]}} && !(_["json"]["errors"].map(&:first) - ["BAD_CAPTCHA"]).empty?

  end
  sleep 60
end
