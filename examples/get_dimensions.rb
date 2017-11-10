require "pp"
# require "json"
# require "nethttputils"
require "imgur2array"
require "fastimage"

module GetDimensions
  class Error < RuntimeError
    def initialize body
      # Module.nesting[1].logger.error body
      super "GetDimensions error: #{body}"
    end
  end

  def self.get_dimensions url
      fail "env var missing -- IMGUR_CLIENT_ID" unless ENV["IMGUR_CLIENT_ID"]
      fail "env var missing -- FLICKR_API_KEY" unless ENV["FLICKR_API_KEY"]
      fail "env var missing -- _500PX_CONSUMER_KEY" unless ENV["_500PX_CONSUMER_KEY"]

      return :skipped if [
        %r{^https://www\.youtube\.com/},
        %r{^http://gfycat\.com/},
        %r{^https?://(i\.)?imgur\.com/.+\.gifv$},
        %r{^https?://www\.reddit\.com/},
        %r{^http://vimeo\.com/},
      ].any?{ |r| r =~ url }
      fi = -> url { _ = FastImage.size url; _ ? [*_, url] : fail }
      [
        ->_{ _ = FastImage.size url; [*_, url] if _ },
        ->_{ if %w{ imgur com } == URI(_).host.split(?.).last(2)
          dimensions = Imgur::imgur_to_array _
          [
            *dimensions.max_by{ |u, x, y| x * y }.rotate(1),
            *dimensions.map(&:first),
          ]
        end },
        ->_{ if %r{^https://www\.flickr\.com/photos/[^/]+/(?<id>[^/]+)} =~ _ ||
                %r{^https://flic\.kr/p/(?<id>[^/]+)$} =~ _
          json = JSON.parse NetHTTPUtils.request_data "https://api.flickr.com/services/rest/", form: {
            method: "flickr.photos.getSizes",
            api_key: ENV["FLICKR_API_KEY"],
            photo_id: id,
            format: "json",
            nojsoncallback: 1,
          }
          raise Error.new "404 for #{_}" if json == {"stat"=>"fail", "code"=>1, "message"=>"Photo not found"}
          if json["stat"] != "ok"
            fail [json, _].inspect
          else
            json["sizes"]["size"].map do |_|
              x, y, u = _.values_at("width", "height", "source")
              [x.to_i, y.to_i, u]
            end.max_by{ |x, y, u| x * y }
          end
        end },
        ->_{ if %r{https?://[^.]+.wiki[mp]edia\.org/wiki(/[^/]+)*/(?<id>File:.+)} =~ _
          _ = JSON.parse NetHTTPUtils.request_data "https://commons.wikimedia.org/w/api.php", form: {
            format: "json",
            action: "query",
            prop: "imageinfo",
            iiprop: "url",
            titles: id,
          }
          fi[_["query"]["pages"].values.first["imageinfo"].first["url"]]
        end },
        ->_{ if %r{^https://500px\.com/photo/(?<id>[^/]+)/[^/]+$} =~ _
          (JSON.parse NetHTTPUtils.request_data "https://api.500px.com/v1/photos/#{id}", form: {
            image_size: 2048,
            consumer_key: ENV["_500PX_CONSUMER_KEY"],
          } )["photo"].values_at("width", "height", "image_url")
        end },
        ->_{ fi[_] },
      ].lazy.map{ |_| _[url] }.find{ |_| _ }
  end
end

if $0 == __FILE__
  STDOUT.sync = true
  puts "self testing..."

[
  ["http://i.imgur.com/7xcxxkR.gifv", :skipped],
  ["http://imgur.com/HQHBBBD", [1024, 768, "https://i.imgur.com/HQHBBBD.jpg",
                                           "https://i.imgur.com/HQHBBBD.jpg"]],
  ["http://imgur.com/a/AdJUK", [1456, 2592, "https://i.imgur.com/Yunpxnx.jpg",
                                            "https://i.imgur.com/Yunpxnx.jpg",
                                            "https://i.imgur.com/3afw2aF.jpg",
                                            "https://i.imgur.com/2epn2nT.jpg"]],
  ["https://www.flickr.com/photos/tomas-/17220613278/", GetDimensions::Error],
  ["https://www.flickr.com/photos/16936123@N07/18835195572", GetDimensions::Error],
  ["https://www.flickr.com/photos/44133687@N00/17380073505/", [3000, 2000, "https://farm8.staticflickr.com/7757/17380073505_ed5178cc6a_o.jpg"]],                            # trailing slash
  ["https://www.flickr.com/photos/jacob_schmidt/18414267018/in/album-72157654235845651/", GetDimensions::Error],                                                            # username in-album
  ["https://www.flickr.com/photos/tommygi/5291099420/in/dateposted-public/", [1600, 1062, "https://farm6.staticflickr.com/5249/5291099420_3bf8f43326_o.jpg"]],              # username in-public
  ["https://www.flickr.com/photos/132249412@N02/18593786659/in/album-72157654521569061/", GetDimensions::Error],
  ["https://www.flickr.com/photos/130019700@N03/18848891351/in/dateposted-public/", [4621, 3081, "https://farm4.staticflickr.com/3796/18848891351_f751b35aeb_o.jpg"]],      # userid   in-public
  ["https://www.flickr.com/photos/frank3/3778768209/in/photolist-6KVb92-eCDTCr-ur8K-7qbL5z-c71afh-c6YvXW-7mHG2L-c71ak9-c71aTq-c71azf-c71aq5-ur8Q-6F6YkR-eCDZsD-eCEakg-eCE6DK-4ymYku-7ubEt-51rUuc-buujQE-ur8x-9fuNu7-6uVeiK-qrmcC6-ur8D-eCEbei-eCDY9P-eCEhCk-eCE5a2-eCH457-eCHrcq-eCEdZ4-eCH6Sd-c71b5o-c71auE-eCHa8m-eCDSbz-eCH1dC-eCEg3v-7JZ4rh-9KwxYL-6KV9yR-9tUSbU-p4UKp7-eCHfwS-6KVbAH-5FrdbP-eeQ39v-eeQ1UR-4jHAGN", [1024, 681, "https://farm3.staticflickr.com/2499/3778768209_280f82abab_b.jpg"]],
  ["https://www.flickr.com/photos/patricksloan/18230541413/sizes/l", [2048, 491, "https://farm6.staticflickr.com/5572/18230541413_fec4783d79_k.jpg"]],
  ["https://flic.kr/p/vPvCWJ", [2048, 1365, "https://farm1.staticflickr.com/507/19572004110_d44d1b4ead_k.jpg"]],
  ["https://en.wikipedia.org/wiki/Prostitution_by_country#/media/File:Prostitution_laws_of_the_world.PNG", [1427, 628, "https://upload.wikimedia.org/wikipedia/commons/e/e8/Prostitution_laws_of_the_world.PNG"]],
  ["http://commons.wikimedia.org/wiki/File:Eduard_Bohlen_anagoria.jpg", [4367, 2928, "https://upload.wikimedia.org/wikipedia/commons/0/0d/Eduard_Bohlen_anagoria.jpg"]],
  ["https://500px.com/photo/112134597/milky-way-by-tom-hall", [4928, 2888, "https://drscdn.500px.org/photo/112134597/m%3D2048_k%3D1_a%3D1/v2?client_application_id=18857&webp=true&sig=c0d31cf9395d7849fbcce612ca9909225ec16fd293a7f460ea15d9e6a6c34257"]],
].each do |input, expectation|
  puts "testing #{input}"
  if expectation == GetDimensions::Error
    begin
      GetDimensions::get_dimensions input
      fail
    rescue GetDimensions::Error
    end
  else
  abort "unable to inspect #{input}" unless result = GetDimensions::get_dimensions(input)
  abort "#{input} :: #{result.inspect} != #{expectation.inspect}" if result != expectation
    # (result.is_a?(Array) ? result[0, 3] : result) != expectation
  end
end

  puts "OK #{__FILE__}"
  exit
end


__END__

  ["http://discobleach.com/wp-content/uploads/2015/06/spy-comic.png", []],
  ["http://spaceweathergallery.com/indiv_upload.php?upload_id=113462", []],
  ["http://livelymorgue.tumblr.com/post/121189724125/may-27-1956-in-an-eighth-floor-loft-of-an#notes", [0, 0]],
http://mobi900.deviantart.com/art/Sea-Sunrise-Wallpaper-545266270
http://mobi900.deviantart.com/art/Sunrise-Field-Wallpaper-545126742


 http://boxtail.deviantart.com/art/Celtic-Water-Orbs-548986856 from http://redd.it/3en92j
http://imgur.com/OXCVSj7&amp;k82U3Qj#0 from http://redd.it/3ee7j1

unable to size http://hubblesite.org/newscenter/archive/releases/2015/02/image/a/format/zoom/ from http://redd.it/2rhm8w
unable to size http://www.deviantart.com/art/Tree-swing-437944764 from http://redd.it/3fnia2

unable to size http://imgur.com/gallery/AsJ3N7x/new from http://redd.it/3fmzdg





found this to be already submitted
[4559, 2727] got from 3foerr: 'https://upload.wikimedia.org/wikipedia/commons/4/47/2009-09-19-helsinki-by-RalfR-062.jpg'
retry download 'https://www.reddit.com/r/LargeImages/search.json?q=url%3Ahttps%3A%2F%2Fupload.wikimedia.org%2Fwikipedia%2Fcommons%2F4%2F47%2F2009-09-19-helsinki-by-RalfR-062.jpg&restrict_sr=on' in 1 seconds because of 503 Service Unavailable

unable to size http://www.flickr.com/photos/dmacs_photos/12027867364/ from http://redd.it/1vqlgk
unable to size https://dl.dropboxusercontent.com/u/52357713/16k.png from http://redd.it/1vomwy

unable to size http://www.flickr.com/photos/dmacs_photos/12027867364/ from http://redd.it/1vqlgk
unable to size https://dl.dropboxusercontent.com/u/52357713/16k.png from http://redd.it/1vomwy

unable http://imgur.com/r/wallpaper/rZ37ZYN from http://redd.it/3knh3g

unable http://www.flickr.com/photos/dmacs_photos/12027867364/ from http://redd.it/1vqlgk


unable http://imgur.com/gallery/jm0OKQM from http://redd.it/3ukg4t
unable http://imgur.com/gallery/oZXfZ from http://redd.it/3ulz2i


