require_relative "../boilerplate"
BOT = RedditBot::Bot.new YAML.load_file "secrets.yaml"

require "gcplogger"
logger = GCPLogger.logger "cptflairbot3"

loop do
  unread = BOT.json :get, "/message/unread"
  unread["data"]["children"].each do |msg|
    next logger.info "bad destination: #{msg["data"]["dest"]}" unless msg["data"]["dest"] == "CPTFlairBot3"
    case msg["data"]["subject"]
    when "casualpokemontrades"
      unless /^(?<name>\S+( \S+)*) ?\n(?<id>\d\d\d\d-\d\d\d\d-\d\d\d\d)\n(?<css_class>\S+)$/ =~ msg["data"]["body"]
        logger.info "invalid message for #{msg["data"]["subject"]}: %p" % msg["data"]["body"] unless Google::Cloud.env.compute_engine?
        # puts "marking invalid message as read: %p" % msg["data"]["body"]
        # BOT.json :post, "/api/read_message", {id: msg["data"]["name"]} unless Gem::Platform.local.os == "darwin"
        next
      end
      if name.size > 50
        logger.info "too large name: %p" % name unless Google::Cloud.env.compute_engine?
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
        }.tap{ |h|
          timeout = 0
          begin
            logger.warn h.merge( {
              messaged_at: Time.at(msg["data"]["created_utc"]),
              processed_at: Time.now,
            } ), {
              subreddit: msg["data"]["subject"],
            }
          rescue Google::Cloud::UnavailableError => e
            logger.info "retrying in #{timeout += 1} seconds because of #{e}"
            sleep timeout
            retry
          end
        }
      rescue RuntimeError => e
        if e.to_s == "BAD_FLAIR_TARGET"
          logger.error "#{e.to_s}: '#{msg["data"]["author"]}'"
        else
          raise e
        end
      end
      BOT.json :post, "/api/read_message", {id: msg["data"]["name"]}
    else
      next logger.debug "bad subject: #{msg["data"]["subject"]}"
    end
    break # just for a case
  end

  logger.info "END LOOP #{Time.now}" unless Google::Cloud.env.compute_engine?
  sleep 60
end
