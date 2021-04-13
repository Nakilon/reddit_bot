module Estimator
  @@quit = false
  Signal.trap("INT") do
    @@quit = true
    puts "quitting..."
  end
  def self.fs_train
    [ [
      [:mean,   false, 50,  true,  0.4,       false, 40, false, 0.000006],
      [:median, false, 120, true,  0.3,       false, 60, false, 0.0005  ],
      [:aa,     false, 40,  false, 0.0000075, false, 40, false, 0.000004],
      [:am,     false, 50,  false, 0.00001,   false, 50, false, 0.000005],
      [:ma,     false, 50,  false, 0.00001,   false, 50, false, 0.000005],
      [:mm,     true,  150, true,  0.3,       false, 70, true,  0.15    ],
      [:ad,     false, 30,  false, 0.0000075, false, 30, false, 0.000003],
      [:md,     false, 50,  true,  0.25,      false, 40, false, 0.00004 ],
    ], %w{
      good/m1q6td.jpg
      bad/m7is26.jpg
      good/m7is3y.jpg
      bad/m1q6ub.jpg
      bad/m7iqem.jpg
      bad/m1q4le.jpg
      bad/lycjnp.jpg
      bad/m1q39s.jpg
      good/lu8flc.jpg
    } ]
  end
  def self.struct
    fs, train = fs_train
    Struct.new \
      *fs.flat_map{ |_,| %i{ s v }.flat_map{ |b| %i{ bhd bdh }.map{ |__| :"#{b}_#{__}_#{_}" } } },
      :width, :height, :size,
      :id, :cls
  end
  def self.analyze file
    fs, train = fs_train
    cache_file = lambda do |id, &block|
      require "yaml"
      filename = "cache/#{id}.yaml"
      if File.exist? filename
        YAML.load_file filename
      else
        block.call.tap{ |_| File.write filename, YAML.dump(_); exit if class_variable_get(:@@quit) }
      end
    end
    cache_dbm = lambda do |id, &block|
      require "dbm"
      DBM.open("cache.dbm") do |dbm| #, 0666, DBM::WRCREAT)
        if dbm.key? id
          dbm.fetch(id).to_f
        else
          block.call.tap{ |_| dbm.store id, _.to_s }
        end
      end.tap{ exit if class_variable_get(:@@quit) }
    end
    require "vips"
    hsv = Vips::Image.new_from_file(file).colourspace("hsv")
    fail unless hsv.bands == 3
    require "digest"
    md5 = Digest::MD5.file file
    struct.new *(
      fs.flat_map do |metric, *rest|
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
    ), hsv.width * 0.0002, hsv.height * 0.0002, File.size(file) * 0.00000005,
      File.basename(file).split(?.).first, file.split(File::SEPARATOR).first.to_sym
  end
  def self.all
    fs, train = fs_train
    train.sort.map &method(:analyze)
  end
end
