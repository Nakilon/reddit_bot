STDOUT.sync = true
require "pp"

if Gem.loaded_specs.include? "nethttputils"
  require "nethttputils"
else
  require_relative "net_http_utils"
end

require "reddit_bot"

require_relative "#{Dir.home}/beat" unless Gem::Platform.local.os == "darwin"

require "yaml"
