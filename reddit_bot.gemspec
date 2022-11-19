Gem::Specification.new do |spec|
  spec.name          = "reddit_bot"
  spec.version       = "1.10.0"
  spec.summary       = "Simple library for Reddit bots"

  spec.author        = "Victor Maslov aka Nakilon"
  spec.email         = "nakilon@gmail.com"
  spec.license       = "MIT"
  spec.metadata      = {"source_code_uri" => "https://github.com/Nakilon/reddit_bot"}

  spec.add_dependency "json_pure"
  spec.add_dependency "nethttputils", "~>0.4.3.0"
  # spec.add_development_dependency "bundler", "~> 1.11"
  # spec.add_development_dependency "rake", "~> 10.0"
  # spec.add_development_dependency "rspec", "~> 3.0"
  spec.required_ruby_version = ">= 2.0.0"

  spec.files         = %w{ LICENSE.txt reddit_bot.gemspec lib/reddit_bot.rb }
end

  # spec.test_files    = ["spec/"]
  # spec.post_install_message = ""
