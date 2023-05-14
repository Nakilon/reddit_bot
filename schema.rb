Schema = {
  body: Hash,
  header: { hash_req: {
    "x-ratelimit-remaining" => /\A\d\d\.0\z/,   # should be <100 to trigger nethttputils delay calculation
    "x-ratelimit-used" => /\A\d\z/,
    "x-ratelimit-reset" => /\A\d\d\d\z/,
  } },
}
require "nakischema"
