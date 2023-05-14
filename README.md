# RedditBot

[![Gem Version](https://badge.fury.io/rb/reddit_bot.svg)](http://badge.fury.io/rb/reddit_bot)

### What

This library provides an easy way to run bots and scripts that use Reddit API.  
I ([/u/nakilon](https://www.reddit.com/u/nakilon)) currently run near 10 bots with it.

### Examples

The [examples folder](examples) includes:

* **sexypizza** -- bot that updates wiki page with current flairs statistics
* **devflairbot** -- bot that flairs posts when some specifically flaired user comments there
* **mlgtv** -- bot that updates sidebar with currently streaming twitch channels
* **councilofricks** -- bot that flairs users according to Google Spreadsheet
* **wallpaper** -- bot that reports images with dimensions being not the same as in title
* **cptflairbot3** -- bot that sets user flair according to request submitted via web form  
  also publishes its activily log here http://www.nakilon.pro/casualpokemontrades/log.htm via Google Cloud Platform automations (Apps Script and Functions)
* **oneplus** -- bot that removes and modmails about links to 1080x1920 images
* **yayornay** -- bot that flairs posts according to voting in top level comments
* **realtimeww2** -- bot that posts tweets to a subreddit from a Twitter user timeline
* **johnnymarr** -- another Twitter timeline streaming bot working in the similar way
* **largeimages** -- this was my first bot -- it uses two approaches to track the most high resolution photos posted anywhere on Reddit to x-post them to [subreddit /r/largeimages](https://www.reddit.com/r/largeimages)
* **largeimagesreview** -- script that was used /r/largeimages to calculates quality of x-posts from different subreddits based on mods activity (remove/approve) so it showed that /r/pics and /r/foodporn should better be excluded:

             pics            Total: 98     Quality: 19%  
          wallpapers         Total: 69     Quality: 52%  
          wallpaper          Total: 45     Quality: 51%  
           woahdude          Total: 30     Quality: 66%  
           CityPorn          Total: 17     Quality: 82%  
           FoodPorn          Total: 13     Quality: 7%  
           MapPorn           Total: 13     Quality: 46%  
           SkyPorn           Total: 11     Quality: 45%  
           carporn           Total: 11     Quality: 45%  
      InfrastructurePorn     Total: 9      Quality: 77%  

         EarthPorn      Total: 23  Quality: 82%   ✅⛔✅✅✅✅⛔✅✅✅✅✅⛔⛔✅✅✅✅✅✅✅✅✅  
          FoodPorn      Total: 5   Quality: 0%    ⛔⛔⛔⛔⛔                   
          carporn       Total: 4   Quality: 0%    ⛔⛔⛔⛔                    
          CityPorn      Total: 4   Quality: 100%  ✅✅✅✅                    
         spaceporn      Total: 4   Quality: 100%  ✅✅✅✅                    
          MapPorn       Total: 4   Quality: 50%   ✅⛔✅⛔                    
       BotanicalPorn    Total: 3   Quality: 66%   ✅✅⛔                     
        CemeteryPorn    Total: 2   Quality: 0%    ⛔⛔                      
        MilitaryPorn    Total: 2   Quality: 50%   ✅⛔                      
        DessertPorn     Total: 2   Quality: 50%   ⛔✅                      
            pic         Total: 2   Quality: 100%  ✅✅                      
      ArchitecturePorn  Total: 2   Quality: 50%   ✅⛔                      
       AbandonedPorn    Total: 2   Quality: 100%  ✅✅                      

### Usage

    $ gem install reddit_bot

or via Gemfile:

    source "https://rubygems.org"
    gem "reddit_bot"

helloworld.rb:

```ruby
require "reddit_bot"
p RedditBot::Bot.new(YAML.load File.read "secrets.yaml").json(:get, "/api/v1/me")
```

The Reddit authorization YAML file format:

    :client_id: Kb9.......6wBw
    :client_secret: Fqo.....................AFI
    :password: mybotpassword
    :login: MyBotUsername

To change log level:

```ruby
RedditBot.logger.level = Logger::ERROR
```

To update the gem version in Gemfile.lock when using Gemfile like this: `gem "reddit_bot", "~>1.1.0"`, do the:

    $ bundle update reddit_bot
