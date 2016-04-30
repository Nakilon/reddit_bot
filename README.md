# RedditBot

[![Join the chat at https://gitter.im/Nakilon/reddit_bot](https://badges.gitter.im/Nakilon/reddit_bot.svg)](https://gitter.im/Nakilon/reddit_bot)
[![Gem Version](https://badge.fury.io/rb/reddit_bot.svg)](http://badge.fury.io/rb/reddit_bot)

#### What

This library provides an easy way to run bots and scripts that use Reddit API.
I (@nakilon) currently run near 10 bots with it.

#### Why

Python (and so PRAW) sucks.

#### Examples

The [examples folder](examples) includes:

* sexypizza -- bot that updates wiki page with current flairs statistics
* iostroubleshooting -- bot that applies flairs to posts (subreddit seems to be suspended)
* mlgtv -- bot that updates sidebar with currently streaming twitch channels
* pokemon_trading -- bot that sets flair to user according to request submitted via PM
* oneplus -- bot that removes and modmails about links to 1080x1920 images
* yayornay -- bot that flairs posts according to voting in top level comments
* largeimages -- useful script for [subreddit /r/largeimages](https://reddit.com/r/largeimages/top)  
  It calculates quality of x-posts from different subreddits based on mods activity (remove/approve).  
  For example, this shows that it would be ok to ignore /r/pics from now:

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

You obviously can't run these examples as is, because they have some dependencies that are not in this repo. Like `secrets.yaml` file for authorization of the following format:

    :client_id: Kb9.......6wBw
    :client_secret: Fqo.....................AFI
    :password: mybotpassword
    :login: MyBotUsername

#### Usage

    $ gem install reddit_bot

helloworld.rb:

    require "reddit_bot"

probably Gemfile:

    source "https://rubygems.org"
    gem "reddit_bot"

TODO: Write usage instructions here  
TODO: manual on how to create bots with Reddit web interface and run via bash console

#### Contributing and License

Bug reports and pull requests are welcome.
The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
