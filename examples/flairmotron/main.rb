require_relative "../boilerplate"

BOT = RedditBot::Bot.new YAML.load(File.read "secrets.yaml"), ignore_captcha: true#, subreddit: SUBREDDIT
SUBREDDIT = "CouncilOfRicks"

CSS_CLASS = "blueflair"

# require "open-uri"
# require "json"
require "csv"

loop do
  AWSStatus::touch

  names, flairs = begin
    JSON.parse DownloadWithRetry::download_with_retry File.read "gas.url"
  rescue JSON::ParserError
    puts "smth wrong with GAS script"
    sleep 60
    retry
  end

  existing = BOT.json(:get, "/r/#{SUBREDDIT}/api/flairlist", limit: 1000)["users"]

  if names.size == flairs.size
    names.zip(flairs).drop(1).map(&:flatten).each_slice(50) do |slice|
      CSV(load = "") do |csv|
        slice.each do |user, text|
          if existing.include?( {"user"=>user, "flair_text"=>text, "flair_css_class"=>CSS_CLASS} )
            puts "skip"
          else
            csv << [user, text, CSS_CLASS]
          end
        end
      end
      BOT.json(:post, "/r/#{SUBREDDIT}/api/flaircsv", [["flair_csv", load]]).each do |report|
        pp report unless report.values_at("errors", "ok", "warnings") == [{}, true, {}]
      end
    end
  else
    puts "columns are different by length"
  end

  sleep 300
end
