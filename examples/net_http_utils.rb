# TODO deprecate in favor of the gem nethttputils

require "net/http"
require "openssl"

require "logger"


module NetHTTPUtils
  class << self

    attr_accessor :logger

    # private?
    def get_response url, mtd = :get, form: {}, header: [], auth: nil, timeout: 30, patch_request: nil, &block
      # form = Hash[form.map{ |k, v| [k.to_s, v] }]
      uri = URI.parse url
      cookies = {}
      prepare_request = lambda do |uri|
        case mtd
          when :get    ; Net::HTTP::Get
          when :post   ; Net::HTTP::Post
          when :put    ; Net::HTTP::Put
          when :delete ; Net::HTTP::Delete
          else         ; raise "unknown method #{mtd}"
        end.new(uri).tap do |request| # somehow Get eats even raw url, not URI object
          patch_request.call uri, form, request if patch_request
          request.basic_auth *auth if auth
          header.each{ |k, v| request[k] = v }
          request["cookie"] = [*request["cookie"], cookies.map{ |k, v| "#{k}=#{v}" }].join "; " unless cookies.empty?
          request.set_form_data form unless form.empty?
          stack = caller.reverse.map do |level|
            /((?:[^\/:]+\/)?[^\/:]+):([^:]+)/.match(level).captures
          end.chunk(&:first).map do |file, group|
            "#{file}:#{group.map(&:last).chunk{|_|_}.map(&:first).join(",")}"
          end
          logger.info request.path
          logger.debug request.each_header.to_a.to_s
          logger.debug stack.join " -> "
          logger.debug request
        end
      end
      request = prepare_request[uri]
      start_http = lambda do |uri|
        begin
          Net::HTTP.start(
            uri.host, uri.port,
            use_ssl: uri.scheme == "https",
            verify_mode: OpenSSL::SSL::VERIFY_NONE,
            # read_timeout: 5,
          ).tap do |http|
            http.read_timeout = timeout #if timeout
            http.open_timeout = timeout #if timeout
            http.set_debug_output STDERR if logger.level == Logger::DEBUG # use `logger.debug?`?
          end
        rescue Errno::ECONNREFUSED => e
          e.message.concat " to #{uri}" # puts "#{e} to #{uri}"
          raise e
        rescue Errno::EHOSTUNREACH, Errno::ENETUNREACH, Errno::ECONNRESET, SocketError, OpenSSL::SSL::SSLError => e
          logger.warn "retrying in 5 seconds because of #{e.class}"
          sleep 5
          retry
        rescue Errno::ETIMEDOUT
          logger.warn "ETIMEDOUT, retrying in 5 minutes"
          sleep 300
          retry
        end
      end
      http = start_http[uri]
      do_request = lambda do |request|
        response = begin
          http.request request, &block
        rescue Errno::ECONNRESET, Errno::ECONNREFUSED, Net::ReadTimeout, Net::OpenTimeout, Zlib::BufError, OpenSSL::SSL::SSLError => e
          logger.error "retrying in 30 seconds because of #{e.class} at: #{request.uri}"
          sleep 30
          retry
        end
        response.to_hash.fetch("set-cookie", []).each{ |c| k, v = c.split(?=); cookies[k] = v[/[^;]+/] }
        case response.code
        when /\A3\d\d$/
          logger.info "redirect: #{response["location"]}"
          new_uri = URI.join(request.uri, response["location"])
          new_host = new_uri.host
          if http.address != new_host ||
             http.port != new_uri.port ||
             http.use_ssl? != (new_uri.scheme == "https")
            logger.debug "changing host from '#{http.address}' to '#{new_host}'"
            http = start_http[new_uri]
          end
          do_request.call prepare_request[new_uri]
        when "404"
          logger.error "404 at #{request.method} #{request.uri} with body: #{
            response.body.is_a?(Net::ReadAdapter) ? "impossible to reread Net::ReadAdapter -- check the IO you've used in block form" : response.body.tap do |body|
              body.replace body.strip.gsub(/<[^>]*>/, "") if body["<html>"]
            end.inspect
          }"
          response
        when /\A50\d$/
          logger.error "#{response.code} at #{request.method} #{request.uri} with body: #{response.body.inspect}"
          response
        else
          logger.info "code #{response.code} at #{request.method} #{request.uri}#{
            " and so #{url}" if request.uri.to_s != url
          } from #{
            [__FILE__, caller.map{ |i| i[/\d+/] }].join ?:
          } with body: #{
            response.body.tap do |body|
              body.replace body.strip.gsub(/<[^>]*>/, "") if body["<html>"]
            end.inspect
          }" unless response.code.start_with? "20"
          response
        end
      end
      do_request[request].tap do |response|
        cookies.each{ |k, v| response.add_field "Set-Cookie", "#{k}=#{v};" }
        logger.debug response.to_hash
      end
    end

    def request_data *args
      response = get_response *args
      throw :"404" if "404" == response.code
      throw :"500" if "500" == response.code
      response.body
    end

  end
  self.logger = Logger.new STDOUT
  self.logger.level = ENV["LOGLEVEL_#{name}"] ? Logger.const_get(ENV["LOGLEVEL_#{name}"]) : Logger::WARN
  self.logger.formatter = lambda do |severity, datetime, progname, msg|
    "#{severity.to_s[0]} #{datetime.strftime "%y%m%d %H%M%S"} : #{name} : #{msg}\n"
  end
end


if $0 == __FILE__
  print "self testing... "

  fail unless NetHTTPUtils.request_data("http://httpstat.us/200") == "200 OK"
  fail unless NetHTTPUtils.get_response("http://httpstat.us/404").body == "404 Not Found"
  catch(:"404"){ fail NetHTTPUtils.request_data "http://httpstat.us/404" }
  # TODO raise?
  fail unless NetHTTPUtils.request_data("http://httpstat.us/400") == "400 Bad Request"
  fail unless NetHTTPUtils.get_response("http://httpstat.us/500").body == "500 Internal Server Error"
  catch(:"500"){ fail NetHTTPUtils.request_data "http://httpstat.us/500" }

  puts "OK #{__FILE__}"
end
