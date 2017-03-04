STDOUT.sync = true
require "pp"

if Gem.loaded_specs.include? "net_http_utils"
  require "net_http_utils"
else
  require_relative "net_http_utils"
end

if ENV["DEV"]
  require_relative "../lib/reddit_bot"
else
  require "reddit_bot"
end

require_relative "#{Dir.home}/beat" unless Gem::Platform.local.os == "darwin"

require "yaml"
