# RedditBot

[![Join the chat at https://gitter.im/Nakilon/reddit_bot](https://badges.gitter.im/Nakilon/reddit_bot.svg)](https://gitter.im/Nakilon/reddit_bot?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge)

[![Gem Version](https://badge.fury.io/rb/reddit_bot.svg)](http://badge.fury.io/rb/mll)  

#### What

This library provides an easy way to run bots and scripts that use Reddit API.
I (@nakilon) currently run 8 bots with it.

#### Why

Python (and so PRAW) sucks.

#### Examples

The [examples folder](examples) includes:

* iostroubleshooting -- (currently active) bot that applies flairs to posts
* mlgtv -- (currently active) bot that updates sidebar with currently streaming twitch channels
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
           ArtPorn           Total: 9      Quality: 22%   
          EarthPorn          Total: 8      Quality: 75%   
          waterporn          Total: 8      Quality: 87%   
           GunPorn           Total: 7      Quality: 85%   
         ExposurePorn        Total: 7      Quality: 57%   
         DessertPorn         Total: 7      Quality: 14%   
         MilitaryPorn        Total: 7      Quality: 57%   
       ArchitecturePorn      Total: 7      Quality: 57%   
          spaceporn          Total: 7      Quality: 14%   
        AbandonedPorn        Total: 6      Quality: 50%   
                                                       
You obviously can't run these examples as is, because they have some dependencies that are not in this repo. Like `secrets` file for authorization of the following format:

    Kb9.......6wBw
    Fqo.....................AFI
    mybotpassword
    MyBotUsername

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
