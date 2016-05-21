STDOUT.sync = true

require "pp"

require "net/http"
require "openssl"
require "json"


module RedditBot
  VERSION = "1.1.6" # :nodoc:

  class Bot

    # bot's Reddit username; set via constructor parameter secrets[:login]
    attr_reader :name

    # [secrets] +Hash+ with keys :client_id, :client_secret, :password: and :login
    # [kwargs] keyword params may include :ignore_captcha that is true by default and :subreddit for clever methods
    def initialize secrets, **kwargs
      @secrets = secrets.values_at *%i{ client_id client_secret password login }
      @name = secrets[:login]
      @ignore_captcha = true
      @ignore_captcha = kwargs[:ignore_captcha] if kwargs.has_key?(:ignore_captcha)
      @subreddit = kwargs[:subreddit]
    end

    # [mtd] +Symbol+ :get or :post
    # [path] +String+ an API method
    # [_form] +Array+ or +Hash+ API method params
    def json mtd, path, _form = []
      form = Hash[_form]
      response = JSON.parse resp_with_token mtd, path, form.merge({api_type: "json"})
      if response.is_a?(Hash) && response["json"] # for example, flairlist.json and {"error": 403} do not have it
        puts "ERROR OCCURED on #{[mtd, path]}" unless response["json"]["errors"].empty?
        # pp response["json"]
        response["json"]["errors"].each do |error, description|
          puts "error: #{[error, description]}"
          case error
          when "ALREADY_SUB" ; puts "was rejected by moderator if you didn't see in dups"
          when "BAD_CAPTCHA" ; update_captcha
            json mtd, path, form.merger( {
              iden: @iden_and_captcha[0],
              captcha: @iden_and_captcha[1],
            } ) unless @ignore_captcha
          else ; fail error
          end
        end
      end
      response
    end

    # [subreddit] +String+ subreddit name without "/r" prefix
    # [page] +String+ page name without "/wiki/" prefix
    # [text] :nodoc:
    def wiki_edit subreddit, page, text
      puts "editing wiki page '/r/#{subreddit}/wiki/#{page}'"
      json :post,
        "/r/#{subreddit}/api/wiki/edit",
        page: page,
        content: text
      # ["previous", result["data"]["children"].last["id"]],
    end

    # [reason] :nodoc:
    # [thing_id] +String+ fullname of a "link, commenr or message"
    def report reason, thing_id
      puts "reporting '#{thing_id}'"
      json :post, "/api/report",
        reason: "other",
        other_reason: reason,
        thing_id: thing_id
    end

    # [post] JSON object of a post of self.post
    # [link_flair_css_class] :nodoc:
    # [link_flair_text] :nodoc:
    def set_post_flair post, link_flair_css_class, link_flair_text
      puts "setting flair '#{link_flair_css_class}' with text '#{link_flair_text}' to post '#{post["name"]}'"
      return puts "possibly not enough permissions for /r/#{@subreddit}/api/flairselector" if {"error"=>403} == @flairselector_choices ||= json(:post, "/r/#{@subreddit}/api/flairselector", link: post["name"])
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
      puts "leaving a comment on '#{thing_id}'"
      json(:post, "/api/comment",
        thing_id: thing_id,
        text: text,
      ).tap do |result|
        fail result["json"]["errors"].to_s unless result["json"]["errors"].empty?
      end
    end

    # :yields: JSON objects: ["data"] part of post or self.post, top level comment (["children"] element)
    def each_new_post_with_top_level_comments
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
      response = JSON.parse reddit_resp :post,
        "https://www.reddit.com/api/v1/access_token", {
          grant_type: "password",
          username: @username = @secrets[3],
          password: @secrets[2],
        }, {
          "User-Agent" => "bot/#{@username}/0.0.0 by /u/nakilon",
        }, [@secrets[0], @secrets[1]]
      unless @token_cached = response["access_token"]
        fail "bot isn't a 'developer' of app at https://www.reddit.com/prefs/apps/" if response == {"error"=>"invalid_grant"}
        fail response.inspect
      end
      puts "new token is: #{@token_cached}"
      update_captcha if "true" == resp_with_token(:get, "/api/needs_captcha", {})
      @token_cached
    end

    def update_captcha
      return if @ignore_captcha
      pp iden_json = json(:post, "/api/new_captcha")
      iden = iden_json["json"]["data"]["iden"]
      # return @iden_and_captcha = [iden, "\n"] if @ignore_captcha
      # pp resp_with_token(:get, "/captcha/#{iden_json["json"]["data"]["iden"]}", {})
      puts "CAPTCHA: https://reddit.com/captcha/#{iden}"
      @iden_and_captcha = [iden, gets.strip]
    end

    def resp_with_token mtd, path, form
      nil until _ = catch(:"401") do
        reddit_resp mtd, "https://oauth.reddit.com" + path, form, {
          "Authorization" => "bearer #{token}",
          "User-Agent" => "bot/#{@username}/0.0.0 by /u/nakilon",
        }
      end
      _
    end

    def reddit_resp *args
      response = nil
      tap do
        response = _resp *args
        case response.code
        when "502", "503", "520", "500", "521", "504", "400", "522"
          puts "LOL #{response.code} at #{Time.now}?"
          pp args
          sleep 5
          redo
        when "409"
          puts "Conflict (409)? at #{Time.now}?"
          pp args
          sleep 5
          redo
        when "401"
          puts "probably token is expired (401): #{response.body}"
          sleep 5
          # init *@secrets
          @token_cached = nil # maybe just update_captcha?
          throw :"401"
        when "403"
          puts "access denied: #{response.body} when requesting: #{args}"
          sleep 5
          # throw :"403"
        when "200"
          "ok"
        else
          # puts response.body if response.code == "400"
          # fail "#{response.code} at '#{args[1]}'"
          fail "#{response.code} for '#{args}'"
        end
      end
      response.body
    end

    def _resp mtd, url, form, headers, base_auth = nil
      uri = URI.parse url
      request = if mtd == :get
        uri.query = URI.encode_www_form form # wtf OpenSSL::SSL::SSLError
        Net::HTTP::Get.new(uri)
      else
        Net::HTTP::Post.new(uri).tap{ |r| r.set_form_data form }
      end
      request.basic_auth *base_auth if base_auth
      headers.each{ |k, v| request[k] = v }
      # puts request.path
      # pp request.to_hash
      # puts request.body
      http = begin # I hope this doesn't need retry (Get|Post).new
        Net::HTTP.start uri.host,
          use_ssl: uri.scheme == "https",
          verify_mode: OpenSSL::SSL::VERIFY_NONE,
          open_timeout: 300
      rescue Errno::ECONNRESET, OpenSSL::SSL::SSLError, Net::OpenTimeout, SocketError => e
        puts "ERROR: #{e.class}: #{e}"
        sleep 5
        retry
      end
      response = begin
        http.request request
      rescue Net::ReadTimeout, Errno::EPIPE, EOFError, SocketError, Zlib::BufError
        puts "ERROR: network"
        retry
      end
      puts %w{
        x-ratelimit-remaining
        x-ratelimit-used
        x-ratelimit-reset
      }.map{ |key| "#{key}=#{response.to_hash[key]}" }.join ", " \
        if ENV["LOGNAME"] == "nakilon"
      # if response.to_hash["x-ratelimit-remaining"]
      #   p response.to_hash["x-ratelimit-remaining"][0]
      #   fail response.to_hash["x-ratelimit-remaining"][0]
      # end
      fail response.to_hash["x-ratelimit-remaining"][0] \
      if response.to_hash["x-ratelimit-remaining"] &&
         response.to_hash["x-ratelimit-remaining"][0].size <= 2

      # if response.code == "401"
      #   puts request.path
      #   puts request.body
      #   pp request.to_hash
      # end

      response
    end

  end

end
