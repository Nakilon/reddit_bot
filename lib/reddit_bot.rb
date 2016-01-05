STDOUT.sync = true

require "pp"

require "net/http"
require "openssl"
require "json"


module RedditBot
  VERSION = "0.1.0"

  class << self

    attr_accessor :token_cached
    attr_accessor :username
    attr_accessor :iden_and_captcha
    attr_accessor :ignore_captcha
    attr_accessor :secrets

    def init *secrets, **kwargs
      @secrets = secrets
      kwargs
      @ignore_captcha = kwargs[:ignore_captcha]
    end

    def json mtd, url, form = []
      response = JSON.parse resp_with_token mtd, url, Hash[form].merge({api_type: "json"})
      if response.is_a?(Hash) && response["json"] # for example, flairlist.json and {"error": 403} do not have it      
        puts "ERROR OCCURED on #{[mtd, url]}" unless response["json"]["errors"].empty?
        # pp response["json"]
        response["json"]["errors"].each do |error, description|
          puts "error: #{[error, description]}"
          case error
          when "ALREADY_SUB" ; puts "was rejected by moderator if you didn't see in dups"
          when "BAD_CAPTCHA" ; update_captcha
            json mtd, url, form.concat([
                                        ["iden", @iden_and_captcha[0]],
                                        ["captcha", @iden_and_captcha[1]],
                                      ]) unless @ignore_captcha
          else ; raise error
          end
        end
      end
      response
    end

    def wiki_edit subreddit, page, text
      json :post,
        "/r/#{subreddit}/api/wiki/edit",
        [
          ["page", page],
          ["content", text]
        ]
      # ["previous", result["data"]["children"].last["id"]],
    end

    private

    def token
      return @token_cached if @token_cached
      response = JSON.parse(reddit_resp(:post,
        "https://www.reddit.com/api/v1/access_token",
        [
          ["grant_type", "password"],
          ["username", @username = @secrets[3]],
          ["password", @secrets[2]],
        ],
        {}, # headers
        [@secrets[0], @secrets[1]],
      ))
      raise response.inspect unless @token_cached = response["access_token"]
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

    def resp_with_token mtd, url, form
      {} until _ = catch(:"401") do
        reddit_resp mtd, "https://oauth.reddit.com" + url, form, [
          ["Authorization", "bearer #{token}"],
          ["User-Agent", "bot/#{@username}/0.0.0 by /u/nakilon"],
        ], nil # base auth
      end
      _
    end

    def reddit_resp *args
      response = nil
      1.times do
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
          puts "access denied: #{response.body}"
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

    def _resp mtd, url, form, headers, base_auth
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
      rescue Errno::ECONNRESET
        puts "ERROR: SSL_connect (Errno::ECONNRESET)"
        sleep 5
        retry
      rescue OpenSSL::SSL::SSLError
        puts "ERROR: SSL_connect SYSCALL returned=5 errno=0 state=SSLv3 read server session ticket A (OpenSSL::SSL::SSLError)"
        sleep 5
        retry
      rescue Net::OpenTimeout
        puts "ERROR: execution expired (Net::OpenTimeout)"
        sleep 5
        retry
      end
      response = begin
        http.request request
      rescue Net::ReadTimeout, Errno::EPIPE # doubt in Errno::EPIPE
        puts "ERROR: Net::ReadTimeout"
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
# /home/ec2-user/largeimages/bot.rb:126:in `_resp': 288 (RuntimeError)
      # File.write File.join(__dir__(), "temp.json"), response.body
# if response.code == "401"
#   puts request.path
#   puts request.body
#   pp request.to_hash
# end
      response
    end

  end

end
