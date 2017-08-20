# usage: `ruby update_gas_hook_secret.rb https://script.google.com/macros/s/.../exec`

File.write "gas_hook_id.secret", ARGV[0][/.+\/([^\/]+)\//, 1]
exec "gsutil cp ./gas_hook_id.secret gs://casualpokemontrades.function.nakilon.pro/"
