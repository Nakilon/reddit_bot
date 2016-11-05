STDOUT.sync = true
require "pp"

require "net_http_utils"

if ENV["DEV"]
  require_relative "../lib/reddit_bot"
else
  require "reddit_bot"
end

require_relative "#{Dir.home}/beat.rb" unless Gem::Platform.local.os == "darwin"

require "yaml"
