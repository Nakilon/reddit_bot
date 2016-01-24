STDOUT.sync = true

require "pp"

require_relative File.join "../..",
  *("../download_with_retry" if ENV["LOGNAME"] == "nakilon"),
  "download_with_retry"

require "reddit_bot"
# RedditBot.init *File.read(File.join(Dir.pwd, "secrets")).split, ignore_captcha: true
RedditBot.init *File.read("secrets").split, ignore_captcha: true

require_relative File.join "../..",
  *(".." if ENV["LOGNAME"] == "nakilon"),
  "awsstatus/2.rb"
