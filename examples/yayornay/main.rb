require_relative "../boilerplate"

# SUBREDDIT = "test___________"
SUBREDDIT = "yayornay"

BOT = RedditBot::Bot.new YAML.load(File.read "secrets.yaml"), ignore_captcha: true, subreddit: SUBREDDIT


loop do
  AWSStatus::touch
  puts "LOOP #{Time.now}"

  BOT.each_new_post_with_top_level_comments do |post, comments|
    yay = []
    nay = []
    comments.each do |comment|
      yay |= [comment["author"]] if comment["body"][/\A\s*yay/i]
      nay |= [comment["author"]] if comment["body"][/\A\s*nay/i]
    end
    p [post["id"], yay, nay] if ENV["LOGNAME"] == "nakilon"
    yay, nay = [(yay - nay).size, (nay - yay).size]
    next if 0 == total = yay + nay
    proper_class = yay > nay ? "yay" : yay < nay ? "nay" : "none"
    proper_text = "#{(100 * yay / total).round}% Yay"
    next if [proper_class, proper_text] == [post["link_flair_css_class"], post["link_flair_text"]]
    puts "setting #{[proper_class, proper_text]} to #{post["name"]}"
    if _ = BOT.set_post_flair(post, proper_class, proper_text)
      fail _.inspect unless _ = {"json"=>{"errors"=>[]}}
    else
      # 403
    end
  end

  puts "END LOOP #{Time.now}"
  sleep 300
end
