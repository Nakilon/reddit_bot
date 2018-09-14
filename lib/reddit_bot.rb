STDOUT.sync = true
# require "pp"

require "net/http"
require "openssl"
require "json"

require "nethttputils"

require_relative "reddit_bot/version" # TODO: deprecate this

module RedditBot
  require "logger"
  class << self
    attr_accessor :logger
  end
  self.logger = Logger.new STDOUT

  class Bot

    # bot's Reddit username; set via constructor parameter secrets[:login]
    attr_reader :name

    # [secrets] +Hash+ with keys :client_id, :client_secret, :password: and :login
    # [kwargs] keyword params may include :subreddit for clever methods
    def initialize secrets, **kwargs
      @name, @secret_password, @user_agent, *@secret_auth = secrets.values_at *%i{ login password user_agent client_id client_secret }
      # @ignore_captcha = true
      # @ignore_captcha = kwargs[:ignore_captcha] if kwargs.has_key?(:ignore_captcha)
      @subreddit = kwargs[:subreddit]
    end

    # [mtd] +Symbol+ :get or :post
    # [path] +String+ an API method
    # [_form] +Array+ or +Hash+ API method params
    def json mtd, path, _form = []
      form = Hash[_form]
      response = JSON.load resp_with_token mtd, path, form.merge({api_type: "json"})
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

    # [reason] :nodoc:
    # [thing_id] +String+ fullname of a "link, commenr or message"
    def report reason, thing_id
      Module.nesting[1].logger.warn "reporting '#{thing_id}'"
      json :post, "/api/report",
        reason: "other",
        other_reason: reason,
        thing_id: thing_id
    end

    # [post] JSON object of a post of self.post
    # [link_flair_css_class] :nodoc:
    # [link_flair_text] :nodoc:
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

    # [thing_id] +String+ fullname of a post (or self.post?), comment (and private message?)
    # [text] :nodoc:
    def leave_a_comment thing_id, text
      Module.nesting[1].logger.warn "leaving a comment on '#{thing_id}'"
      json(:post, "/api/comment",
        thing_id: thing_id,
        text: text,
      ).tap do |result|
        fail result["json"]["errors"].to_s unless result["json"]["errors"].empty?
      end
    end

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
          fail result["data"].keys.inspect unless result["data"].keys == %w{ after dist modhash whitelist_status children before } ||
                                                  result["data"].keys == %w{ modhash dist children after before }
          result["data"]["children"].each do |post|
            fail "unknown type post['kind']: #{post["kind"]}" unless post["kind"] == "t3"
            e << post["data"]
          end
          break unless marker = result["data"]["after"]
          after = {after: marker}
        end
      end
    end

    # :yields: JSON objects: ["data"] part of post or self.post, top level comment (["children"] element)
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

    # [article] +String+ ID36 of a post or self.post
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
          "User-Agent" => "bot/#{@user_agent || @name}/#{RedditBot::VERSION} by /u/nakilon",
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
      begin
        reddit_resp mtd, "https://oauth.reddit.com" + path, form, {
          "Authorization" => "bearer #{token}",
          "User-Agent" => "bot/#{@user_agent || @name}/#{RedditBot::VERSION} by /u/nakilon",
        }
      rescue NetHTTPUtils::Error => e
        sleep 5
        raise unless e.code == 401
        @token_cached = nil
        retry
      end
    end

    def reddit_resp *args
      mtd, url, form, headers, basic_auth = *args
      begin
        NetHTTPUtils.request_data(url, mtd, form: form, header: headers, auth: basic_auth) do |response|
          next unless remaining = response.to_hash["x-ratelimit-remaining"]
          if Gem::Platform.local.os == "darwin"
            Module.nesting[1].logger.debug %w{
              x-ratelimit-remaining
              x-ratelimit-used
              x-ratelimit-reset
            }.map{ |key| "#{key}=#{response.to_hash[key]}" }.join ", "
          end
          fail remaining[0] if remaining[0].size < 4
          next if remaining[0].size > 4
          t = (response.to_hash["x-ratelimit-reset"][0].to_f + 1) / [remaining[0].to_f - 10, 1].max + 1
          Module.nesting[1].logger.info "sleeping #{t} seconds because of x-ratelimit"
          sleep t
        end
      rescue NetHTTPUtils::Error => e
        sleep 5
        raise unless e.code.to_s.start_with? "50"
        Module.nesting[1].logger.error "API ERROR 50*"
        retry
      end
    end

  end
end
