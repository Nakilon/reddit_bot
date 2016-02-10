STDOUT.sync = true

require "pp"

require_relative File.join "../..",
  *("../download_with_retry" if ENV["LOGNAME"] == "nakilon"),
  "download_with_retry"

require "reddit_bot"

if RedditBot::VERSION <= "0.1.3"

  RedditBot.init *File.read("secrets").split, ignore_captcha: true

end

require_relative File.join "../..",
  *(".." if ENV["LOGNAME"] == "nakilon"),
  "awsstatus/2.rb"

require "yaml"
