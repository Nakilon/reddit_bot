STDOUT.sync = true

require "pp"

require_relative File.join "../..",
  *("../download_with_retry" if ENV["LOGNAME"] == "nakilon"),
  "download_with_retry"

if ENV["DEV"]
  require_relative "../lib/reddit_bot"
else
  require "reddit_bot"
end

RedditBot.init *File.read("secrets").split, ignore_captcha: true if RedditBot::VERSION <= "0.1.3"

require_relative File.join "../..",
  *(".." if ENV["LOGNAME"] == "nakilon"),
  "awsstatus/2.rb"

require "yaml"
