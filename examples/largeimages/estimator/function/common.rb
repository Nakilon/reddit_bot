module Estimator
  @@quit = false
  Signal.trap("INT") do
    @@quit = true
    puts "quitting..."
  end
  class << self
    attr_accessor :get_fs
    attr_accessor :get_train
  end
  def self.struct
    Struct.new \
      *get_fs.flat_map{ |_,| %i{ s v }.flat_map{ |b| %i{ bhd bdh }.map{ |__| :"#{b}_#{__}_#{_}" } } },
      :width, :height, :size,
      :id, :cls
  end
  def self.analyze file, no_cache = false   # no_cache is currently a synonim to kinda parse_filename
    mean = ->(arr){ arr.inject(:+).fdiv arr.size }
    median = ->(arr){ arr.size.odd? ? arr.sort[arr.size/2] : mean[arr.sort[arr.size/2-1,2]] }
    aa = ->(arr){   mean[ arr.map{ |_| (_ -   mean[arr]).abs } ] }
    ma = ->(arr){ median[ arr.map{ |_| (_ -   mean[arr]).abs } ] }
    am = ->(arr){   mean[ arr.map{ |_| (_ - median[arr]).abs } ] }
    mm = ->(arr){ median[ arr.map{ |_| (_ - median[arr]).abs } ] }
    ad = lambda do |arr| # Mean absolute difference
      mean.call arr.product(arr).map{ |a,b| (a-b).abs }
    end
    md = lambda do |arr|
      median.call arr.product(arr).map{ |a,b| (a-b).abs }
    end
    cache_file = lambda do |id, &block|
      require "yaml"
      filename = "cache/#{id}.yaml"
      if File.exist? filename
        YAML.load_file filename
      else
        block.call.tap{ |_| File.write filename, YAML.dump(_) unless no_cache; exit if class_variable_get(:@@quit) }
      end
    end
    cache_dbm = lambda do |id, &block|
      require "dbm"
      DBM.open("cache.dbm") do |dbm| #, 0666, DBM::WRCREAT)
        if dbm.key? id
          dbm.fetch(id).to_f
        else
          block.call.tap{ |_| dbm.store id, _.to_s unless no_cache }
        end
      end.tap{ exit if class_variable_get(:@@quit) }
    end
    require "vips"
    hsv = Vips::Image.new_from_file(file).colourspace("hsv")
    fail unless hsv.bands == 3
    require "digest"
    md5 = Digest::MD5.file file
    fs_vector = get_fs.flat_map do |metric, *rest|
        rest.each_slice(2).zip(
          %i{ s v }.zip(hsv.bandsplit[1,2]).flat_map do |band_name, band|
            hist1 = cache_file.call("#{md5}-#{band_name}-blur_hist_diff") do
              ((band.hist_find - band.+(0).gaussblur(1).hist_find).abs / band.hist_find.max).to_a.flatten
            end
            hist2 = cache_file.call("#{md5}-#{band_name}-blur_diff_hist") do
              (band - band.+(0).gaussblur(1)).abs.*(10).hist_find.to_a.flatten
            end
            %i{ blur_hist_diff blur_diff_hist }.zip([hist1, hist2]).map do |hist_name, hist|
              cache_dbm.call("#{Digest::MD5.hexdigest hist.to_s}-#{metric}-#{band_name}-#{hist_name}") do
                binding.local_variable_get(metric).call hist
              end
            end
          end
        ).map{ |(log, r), v| (log ? Math::log(v+1) : v) * r }
    end
    if no_cache
      struct.new *(
        fs_vector
      ), hsv.width * 0.0002, hsv.height * 0.0002, File.size(file) * 0.00000005
    else
    struct.new *(
      fs_vector
    ), hsv.width * 0.0002, hsv.height * 0.0002, File.size(file) * 0.00000005,
      File.basename(file).split(?.).first, file.split(File::SEPARATOR).first.to_sym
    end
  end
  def self.all
    get_train.sort.map &method(:analyze)
  end
end
