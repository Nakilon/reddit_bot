require_relative File.join "..", "boilerplate"

# SUBREDDIT = "test___________"
SUBREDDIT = "iostroubleshooting"

# require "open-uri"
require "csv" # /api/flaircsv

loop do
  AWSStatus::touch
  catch :loop do

    existing = RedditBot.json(:get, "/r/#{SUBREDDIT}/api/flairlist")["users"]
    begin
      JSON.parse(DownloadWithRetry::download_with_retry("#{File.read "gas.url"}sheet_name=Bot&spreadsheet_id=10UzXUbawBgXLQkxXDMz28Qcx3IQPjwG9nByd_d8y31I", &:read))
    rescue JSON::ParserError
      puts "smth wrong with GAS script"
      throw :loop
    end.drop(1).reverse.uniq{ |_, user, _, _| user }.map do |row|
      next unless row.map(&:empty?) == [false, false, false, false]
      _, user, ios, flair = row
      next if existing.include?({"flair_css_class"=>flair, "user"=>user, "flair_text"=>ios})
      [user, ios, flair]
      # {"iPhone"=>"greenflair", "iPad"=>"blue", "iPod"=>"red"}[device[/iP(od|ad|hone)/]]]
    end.compact.each_slice(50) do |slice|
      CSV(load = ""){ |csv| slice.each{ |record| csv << record } }
      puts load
      RedditBot.json(:post, "/r/#{SUBREDDIT}/api/flaircsv", [["flair_csv", load]]).each do |report|
        pp report unless report.values_at("errors", "ok", "warnings") == [{}, true, {}]
      end
    end

  end
  sleep 60
end
