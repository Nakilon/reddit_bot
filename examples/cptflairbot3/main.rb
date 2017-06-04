require_relative "../boilerplate"
BOT = RedditBot::Bot.new YAML.load File.read "secrets.yaml"

loop do
  Hearthbeat.beat "u_CPTFlairBot3_r_casualpokemontrades", 70 unless Gem::Platform.local.os == "darwin"

  unread = BOT.json :get, "/message/unread"
  unread["data"]["children"].each do |msg|
    next puts "bad destination: #{msg["data"]["dest"]}" unless msg["data"]["dest"] == "CPTFlairBot3"
    case msg["data"]["subject"]
    when "casualpokemontrades"
      unless /^(?<name>\S+)\n(?<id>\d\d\d\d-\d\d\d\d-\d\d\d\d)\n(?<css_class>\S+)$/ =~ msg["data"]["body"]
        puts "invalid message for #{msg["data"]["subject"]}: %p" % msg["data"]["body"] if Gem::Platform.local.os == "darwin"
        # puts "marking invalid message as read: %p" % msg["data"]["body"]
        # BOT.json :post, "/api/read_message", {id: msg["data"]["name"]} unless Gem::Platform.local.os == "darwin"
        next
      end
      begin
        BOT.json :post, "/r/#{msg["data"]["subject"]}/api/flair", {
          name: msg["data"]["author"],
          text: {
            "casualpokemontrades" => "#{id} | #{name}",
            "relaxedpokemontrades" => "#{name} #{id}",
          }[msg["data"]["subject"]],
          css_class: css_class,
        }.tap{ |h| puts "setting up flair at /r/#{msg["data"]["subject"]}: #{h}" }
      rescue RuntimeError => e
        if e.to_s == "BAD_FLAIR_TARGET"
          puts "#{e.to_s}: '#{msg["data"]["author"]}'"
        else
          raise e
        end
      end
      BOT.json :post, "/api/read_message", {id: msg["data"]["name"]}
    else
      next puts "bad subject: #{msg["data"]["subject"]}"
    end
    break # just for a case
  end

  puts "END LOOP #{Time.now}" if Gem::Platform.local.os == "darwin"
  sleep 60
end
