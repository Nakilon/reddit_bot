STDOUT.sync = true

require "openssl"
require "json"
require "yaml"

require "nethttputils"

module RedditBot
  require "logger"
  class << self
    attr_accessor :logger
  end
  self.logger = Logger.new STDOUT

  class Bot
    attr_reader :name

    def initialize secrets, **kwargs
      @name, @secret_password, @user_agent, *@secret_auth = secrets.values_at *%i{ login password user_agent client_id client_secret }
      # @ignore_captcha = true
      # @ignore_captcha = kwargs[:ignore_captcha] if kwargs.has_key?(:ignore_captcha)
      @subreddit = kwargs[:subreddit]
    end

    def json mtd, path, _form = []
      form = Hash[_form]
      response = begin
        JSON.load resp_with_token mtd, path, form.merge({api_type: "json"})
      rescue JSON::ParserError
        $!.message.slice! 1000..-1
        raise
      end
      if response.is_a?(Hash) && response["json"] && # for example, flairlist.json and {"error": 403} do not have it
         !response["json"]["errors"].empty?
        Module.nesting[1].logger.error "ERROR OCCURED on #{[mtd, path]}"
        fail "unknown how to handle multiple errors" if 1 < response["json"]["errors"].size
        Module.nesting[1].logger.error "error: #{response["json"]["errors"]}"
        error, description = response["json"]["errors"].first
          case error
          when "ALREADY_SUB" ; Module.nesting[1].logger.warn "was rejected by moderator if you didn't see in dups"
          # when "BAD_CAPTCHA" ; update_captcha
          #   json mtd, path, form.merger( {
          #     iden: @iden_and_captcha[0],
          #     captcha: @iden_and_captcha[1],
          #   } ) unless @ignore_captcha
          when "RATELIMIT"
            fail error unless description[/\Ayou are doing that too much\. try again in (\d) minutes\.\z/]
            Module.nesting[1].logger.info "retrying in #{$1.to_i + 1} minutes"
            sleep ($1.to_i + 1) * 60
            return json mtd, path, _form
          else ; fail error
          end
      end
      response
    end

    # # [subreddit] +String+ subreddit name without "/r" prefix
    # # [page] +String+ page name without "/wiki/" prefix
    # # [text] :nodoc:
    # def wiki_edit subreddit, page, text
    #   puts "editing wiki page '/r/#{subreddit}/wiki/#{page}'"
    #   json :post,
    #     "/r/#{subreddit}/api/wiki/edit",
    #     page: page,
    #     content: text
    #   # ["previous", result["data"]["children"].last["id"]],
    # end

    def report reason, thing_id
      Module.nesting[1].logger.warn "reporting '#{thing_id}'"
      json :post, "/api/report",
        reason: "other",
        other_reason: reason,
        thing_id: thing_id
    end

    def set_post_flair post, link_flair_css_class, link_flair_text
      Module.nesting[1].logger.warn "setting flair '#{link_flair_css_class}' with text '#{link_flair_text}' to post '#{post["name"]}'"
      if {"error"=>403} == @flairselector_choices ||= json(:post, "/r/#{@subreddit}/api/flairselector", link: post["name"])
        Module.nesting[1].logger.error "possibly not enough permissions for /r/#{@subreddit}/api/flairselector"
        return
      end
      json :post, "/api/selectflair",
        link: post["name"],
        text: link_flair_text,
        flair_template_id: @flairselector_choices["choices"].find{ |i| i["flair_css_class"] == link_flair_css_class }.tap{ |flair|
          fail "can't find '#{link_flair_css_class}' flair class at https://www.reddit.com/r/#{@subreddit}/about/flair/#link_templates" unless flair
        }["flair_template_id"]
    end

    def leave_a_comment thing_id, text
      Module.nesting[1].logger.warn "leaving a comment on '#{thing_id}'"
      json(:post, "/api/comment",
        thing_id: thing_id,
        text: text,
      ).tap do |result|
        fail result["json"]["errors"].to_s unless result["json"]["errors"].empty?
      end
    end

    @@skip_erroneous_descending_ids = lambda do |array|
      array.reverse.each_with_object([]) do |item, result|
        unless result.empty?
          a, b = [item["id"], result.first["id"]]
          next if a == b || a.size < b.size || !(a.size > b.size) && a < b
        end
        result.unshift item
      end
    end
    fail unless @@skip_erroneous_descending_ids[[
      {"id" => "0h"},
      {"id" => "g"},
      {"id" => "f"},
      {"id" => "i"},
      {"id" => "e"},
      {"id" => "b"},
      {"id" => "c"},
      {"id" => "d"},
    ]].flat_map(&:values) == %w{ 0h i e d }
    # :yields: JSON objects: ["data"] part of post or self.post
    def new_posts subreddit = nil, caching = false
      cache = lambda do |id, &block|
        next block.call unless caching
        require "fileutils"
        FileUtils.mkdir_p "cache"
        filename = "cache/#{Digest::MD5.hexdigest id.inspect}"
        next YAML.load File.read filename if File.exist? filename
        block.call.tap do |data|
          File.write filename, YAML.dump(data)
        end
      end
      Enumerator.new do |e|
        after = {}
        loop do
          # TODO maybe force lib user to prepend "r/" to @subreddit constructor?
          args = [:get, "/#{subreddit || (@subreddit ? "r/#{@subreddit}" : fail)}/new", {limit: 100}.merge(after)]
          result = cache.call(args){ json *args }
          fail if result.keys != %w{ kind data }
          fail if result["kind"] != "Listing"
          fail result["data"].keys.inspect unless [
                                                    %w{ after dist modhash whitelist_status children before },
                                                    %w{ modhash dist children after before },
                                                    %w{ after dist modhash geo_filter children before },
                                                  ].include? result["data"].keys
          @@skip_erroneous_descending_ids[ result["data"]["children"].map do |post|
            fail "unknown type post['kind']: #{post["kind"]}" unless post["kind"] == "t3"
            post["data"].dup.tap do |data|
              data["url"] = "https://www.reddit.com" + data["url"] if /\A\/r\/[0-9a-zA-Z_]+\/comments\/[0-9a-z]{5,6}\// =~ data["url"] if data["crosspost_parent"]
            end
          end ].each do |data|
            e << data
          end
          break unless marker = result["data"]["after"]
          after = {after: marker}
        end
      end
    end

    def each_new_post_with_top_level_comments
      # TODO add keys assertion like in method above?
      json(:get, "/r/#{@subreddit}/new")["data"]["children"].each do |post|
        fail "unknown type post['kind']: #{post["kind"]}" unless post["kind"] == "t3"
        t = json :get, "/comments/#{post["data"]["id"]}", depth: 1, limit: 100500#, sort: "top"
        fail "smth weird about /comments/<id> response" unless t.size == 2
        yield post["data"], t[1]["data"]["children"].map{ |child|
          fail "unknown type child['kind']: #{child["kind"]}" unless child["kind"] == "t1"
          child["data"]
        }.to_enum
      end
    end

    def each_comment_of_the_post_thread article
      Enumerator.new do |e|
        f = lambda do |smth|
          smth["data"]["children"].each do |child|
            f[child["data"]["replies"]] if child["data"]["replies"].is_a? Hash
            fail "unknown type child['kind']: #{child["kind"]}" unless child["kind"] == "t1"
            e << [child["data"]["name"], child["data"]]
          end
        end
        f[ json(:get, "/comments/#{article}", depth: 100500, limit: 100500).tap do |t|
          fail "smth weird about /comments/<id> response" unless t.size == 2
        end[1] ]
      end
    end

    def subreddit_iterate what, **kwargs
      Enumerator.new do |e|
        after = {}
        loop do
          break unless marker = json(:get, "/r/#{@subreddit}/#{what}", {limit: 100}.merge(after).merge(kwargs)).tap do |result|
            fail if %w{ kind data } != result.keys
            fail if "Listing" != result["kind"]
            fail result["data"].keys.inspect unless result["data"].keys == %w{ after dist modhash whitelist_status children before } ||
                                                    result["data"].keys == %w{ modhash dist children after before }
            result["data"]["children"].each do |post|
              fail "unknown type post['kind']: #{post["kind"]}" unless post["kind"] == "t3"
              e << ( post["data"].tap do |data|
                data["url"] = "https://www.reddit.com" + data["url"] if /\A\/r\/[0-9a-zA-Z_]+\/comments\/[0-9a-z]{5,6}\// =~ data["url"] if data["crosspost_parent"]
              end )
            end
          end["data"]["after"]
          after = {after: marker}
        end
      end
    end

    private

    def token
      return @token_cached if @token_cached
      # TODO handle with nive error message if we get 403 -- it's probably because of bad user agent
      response = JSON.load reddit_resp :post,
        "https://www.reddit.com/api/v1/access_token", {
          grant_type: "password",
          username: @name,
          password: @secret_password,
        }, {
          "User-Agent" => "bot/#{@user_agent || @name}/#{Gem::Specification::load("#{__dir__}/../reddit_bot.gemspec").version} by /u/nakilon",
        }, @secret_auth
      unless @token_cached = response["access_token"]
        fail "bot #{@name} isn't a 'developer' of app at https://www.reddit.com/prefs/apps/" if response == {"error"=>"invalid_grant"}
        fail response.inspect
      end
      Module.nesting[1].logger.info "new token is: #{@token_cached}"
      # update_captcha if "true" == resp_with_token(:get, "/api/needs_captcha", {})
      @token_cached
    end

    # def update_captcha
    #   return if @ignore_captcha
    #   pp iden_json = json(:post, "/api/new_captcha")
    #   iden = iden_json["json"]["data"]["iden"]
    #   # return @iden_and_captcha = [iden, "\n"] if @ignore_captcha
    #   # pp resp_with_token(:get, "/captcha/#{iden_json["json"]["data"]["iden"]}", {})
    #   puts "CAPTCHA: https://reddit.com/captcha/#{iden}"
    #   @iden_and_captcha = [iden, gets.strip]
    # end

    def resp_with_token mtd, path, form
      fail unless path.start_with? ?/
      timeout = 5
      begin
        reddit_resp mtd, "https://oauth.reddit.com" + path, form, {
          "Authorization" => "bearer #{token}",
          "User-Agent" => "bot/#{@user_agent || @name}/#{Gem::Specification::load("#{__dir__}/../reddit_bot.gemspec").version} by /u/nakilon",
        }
      rescue NetHTTPUtils::Error => e
        raise unless e.code == 401
        sleep timeout
        Module.nesting[1].logger.info "sleeping #{timeout} seconds because of #{e.code}"
        timeout *= 2
        @token_cached = nil
        retry
      end
    end

    def reddit_resp *args
      mtd, url, form, headers, basic_auth = *args
      headers["Cookie:"] = "over18=1"
      begin
        NetHTTPUtils.request_data url, mtd, form: form, header: headers, auth: basic_auth
      rescue NetHTTPUtils::Error => e
        sleep 5
        raise unless e.code.to_s.start_with? "50"
        Module.nesting[1].logger.error "API ERROR 50*"
        retry
      end
    end

  end

  module Twitter
    require "json"

    def self.init_twitter twitter
      const_set :TWITTER_ACCOUNT, twitter
      const_set :TWITTER_ACCESS_TOKEN, JSON.load(
        NetHTTPUtils.request_data "https://api.twitter.com/oauth2/token", :post,
          auth: File.read("twitter.token").split,
          form: {grant_type: :client_credentials}
      )["access_token"]
    end

    require "cgi"
    def self.tweet2titleNtext tweet
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
      } [^\\(@#{TWITTER_ACCOUNT}\\)](https://twitter.com/#{TWITTER_ACCOUNT}) ^| [#{
        up[Date.parse(tweet["created_at"]).strftime "%B %-d, %Y"]
      }](https://twitter.com/#{TWITTER_ACCOUNT}/status/#{tweet["id"]})"
      [CGI::unescapeHTML(tweet["full_text"]).sub(/( https:\/\/t\.co\/[0-9a-zA-Z]{10})*\z/, ""), text, contains_media]
    end

    def self.user_timeline
      timeout = 1
      JSON.load begin
        NetHTTPUtils.request_data(
          "https://api.twitter.com/1.1/statuses/user_timeline.json",
          form: { screen_name: TWITTER_ACCOUNT, count: 200, tweet_mode: "extended" },
          header: { Authorization: "Bearer #{TWITTER_ACCESS_TOKEN}" }
        )
      rescue NetHTTPUtils::Error => e
        fail unless [500, 503].include? e.code
        sleep timeout
        timeout *= 2
        retry
      end
    end
  end

end
