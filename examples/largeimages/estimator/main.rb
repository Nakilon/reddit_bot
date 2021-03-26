# $ PLOT=_ cpulimit -i -l 50 ruby main.rb
# $        cpulimit -i -l 50 ruby main.rb

require "pp"

quit = false
Signal.trap("INT") do
  quit = true
  puts "quitting..."
end

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
    block.call.tap{ |_| File.write filename, YAML.dump(_); exit if quit }
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
  end.tap{ exit if quit }
end

optimize = lambda do |exc_set = [], exc_fs = []|
  fs, train = [
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
  }

  struct = Struct.new \
    *fs.flat_map{ |_,| %i{ s v }.flat_map{ |b| %i{ bhd bdh }.map{ |__| :"#{b}_#{__}_#{_}" } } },
    :width, :height, :size,
    :id, :cls
  all = train.sort.map do |file|
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
  logs = struct.new *(
    fs.flat_map do |_, *rest|
      rest.each_slice(2).map{ |log, _| log }
    end
  ), false, false, false

  logs.to_h.compact.each do |f, log|
    min, max = all.map(&f).minmax
    puts "#{f}#{" (log)" if log}: #{(max - min).round 3}"
    if ENV["PLOT"]
      require "unicode_plot"
      require "io/console"
      all.each{ |_| p _.to_h.values_at :cls, :id, f }
      UnicodePlot.lineplot(all.size.times.to_a, all.map(&f).sort, labels: false, width: IO.console.winsize[1]-7).render
    end
  end
  exit if ENV["PLOT"]

  require "set"
  require "pcbr"
  ds = struct.new *(logs.to_h.compact.map do |f,|
    all.map do |i|
      all.map do |j|
        (i[f] - j[f]) * (i[f] - j[f])
      end
    end
  end)
  pcbr = PCBR.new
  pcbr_set = Set.new
  best = nil
  prev_time = nil

  combinations = [[logs.to_h.compact.keys - exc_fs, all.size.times.to_a - exc_set]]

  loop do
    combinations.each do |fs, set|
      t = all.size.times.map do |i|
        {
          %i{ good  bad } => :fp,
          %i{  bad good } => :fn,
          %i{ good good } => :tp,
          %i{  bad  bad } => :tn,
        }[ [
          all[i].cls,
          all[
            (set-[i]).min_by{ |j|
              fs.sum{ |f| ds[f][i][j] }
            }
          ].cls,
        ] ]
      end
      tp = t.count :tp
      d = (tp + t.count(:fp)) * (tp + t.count(:fn))
      pcbr.store [fs, set], [
        d.zero? ? 0 : (tp * tp).fdiv(d),
        [-fs.size, -set.size]
      ]
      p pcbr.table.size if pcbr.table.size % 100 == 0
    end
    if best != t = pcbr.table.max_by{ |_,(fm,_),| fm }.tap{ |(f,set),(fm,_),| break [fm, set, f] }
      best, prev_time = t, Time.now
      p best
    end
    combinations = pcbr.table.sort_by{ |_, _, score| -score }.lazy.map do |(f, set),|
      next [] if pcbr_set.member? [f, set]
      pcbr_set.add [f, set]
      [
        *f.size.times.map{ |i|
          next if f.size < 2
          key = f.dup.tap{ |_| _.delete_at i }
          [key, set] unless pcbr.set.member? [key, set]
        },
        *set.size.times.map{ |i|
          next if set.size < 3
          key = set.dup.tap{ |_| _.delete_at i }
          [f, key] unless pcbr.set.member? [f, key]
        },
      ].compact
    end.drop_while(&:empty?).first
    break puts "all combinations tested" unless combinations
    abort "wtf" if combinations.empty?
    break if Time.now - prev_time > 60 && pcbr.table.size > 10000
    exit if quit
  end

  best, g = pcbr.table.group_by{ |_,(fm,_),| fm }.max_by(&:first)
  p best
  g.each{ |(f,set),(fm,_),| p [f, all.values_at(*set).map(&:id)] }

  require "unicode_plot"
  fh, sh = {}, {}
  pcbr.table.each do |(f,set), (fm,_), score|
    f.  each{ |_| fh[_]||=[] ; fh[_].push score }
    set.each{ |_| sh[_]||=[] ; sh[_].push score }
  end

  fh.each{ |i, a| UnicodePlot.histogram(a, nbins: 10, title: i          ,         xlabel: "").render }
  sh.each{ |i, a| UnicodePlot.histogram(a, nbins: 10, title: [i, all[i].id].to_s, xlabel: "").render }

end

# optimize.call
# 0.6666666666666666
# [[:s_bhd_mean, :s_bhd_median, :s_bhd_aa, :v_bhd_aa, :v_bhd_ma, :v_bdh_ad, :width], ["m1q39s", "m1q4le", "m1q6ub", "m7is26", "lu8flc", "m1q6td"]]
# [[:s_bhd_mean, :v_bhd_mean, :s_bhd_median, :s_bhd_aa, :v_bdh_ad, :width], ["m1q39s", "m1q4le", "m1q6ub", "m7is26", "lu8flc", "m1q6td"]]
# s_bdh_median v_bdh_median v_bhd_am s_bdh_mm v_bdh_md height
# [0, "lycjnp"] [4, "m7iqem"] [8, "m7is3y"]

# optimize.call [0, 4, 8], %i{ s_bdh_median v_bdh_median v_bhd_am s_bdh_mm v_bdh_md height }
# 0.75
# [[:s_bhd_md], ["m1q39s", "m1q4le", "m7is26", "lu8flc", "m1q6td"]]

# optimize.call [0, 4], %i{ v_bhd_am s_bdh_mm v_bdh_md }
# 0.6
# [[:v_bhd_median, :s_bhd_md, :s_bdh_md], ["m1q39s", "m1q4le", "lu8flc", "m1q6td"]]
# [[:v_bhd_median, :s_bhd_aa, :s_bdh_md], ["m1q39s", "m1q4le", "lu8flc", "m1q6td"]]
# [[:v_bhd_median, :v_bdh_median, :s_bhd_md], ["m1q39s", "m1q4le", "lu8flc", "m1q6td"]]

# optimize.call [0, 4], %i{ s_bdh_median v_bdh_median v_bhd_am s_bdh_mm v_bdh_md height }
# 0.75
# [[:s_bhd_mean, :s_bhd_am, :s_bhd_mm], ["m1q39s", "m1q4le", "m7is26", "lu8flc", "m1q6td"]]
# [[:s_bhd_md], ["m1q39s", "m1q4le", "m7is26", "lu8flc", "m1q6td"]]

# optimize.call [0, 4], %i{ v_bhd_am s_bdh_mm }
# 0.5
# [[:s_bhd_md], ["m1q39s", "m1q4le", "lu8flc", "m1q6td"]]
# [[:s_bhd_ad], ["m1q39s", "m1q4le", "lu8flc", "m1q6td"]]
# [[:s_bhd_am], ["m1q39s", "m1q4le", "lu8flc", "m1q6td"]]
# [[:s_bhd_mean], ["m1q39s", "m1q4le", "lu8flc", "m1q6td"]]

# optimize.call [0, 4], %i{ v_bhd_am s_bdh_mm v_bdh_mean s_bhd_median }
# 0.6
# [[:s_bhd_ma, :v_bhd_mm, :v_bdh_md], ["m1q39s", "lu8flc", "m1q6td"]]
# [[:v_bdh_median, :v_bhd_mm, :s_bhd_ad], ["m1q39s", "m1q4le", "lu8flc", "m1q6td"]]

# optimize.call
# 0.75
# [[:s_bdh_mm, :s_bhd_ad], ["m1q39s", "m1q6ub", "m1q6td", "m7is3y"]]
# [[:s_bdh_mm, :s_bhd_ad], ["m1q39s", "m1q4le", "m1q6td", "m7is3y"]]
# [[:s_bhd_am, :s_bdh_mm], ["m1q39s", "m1q6ub", "m1q6td", "m7is3y"]]
# [[:s_bhd_am, :s_bdh_mm], ["m1q39s", "m1q4le", "m1q6td", "m7is3y"]]
# [[:s_bhd_am, :s_bdh_mm], ["m1q39s", "m1q6ub", "lu8flc", "m1q6td"]]
# [[:s_bhd_am, :s_bdh_mm], ["m1q39s", "m1q6ub", "lu8flc", "m7is3y"]]
# [[:s_bhd_am, :s_bdh_mm], ["m1q39s", "m1q4le", "lu8flc", "m7is3y"]]
# [[:s_bhd_am, :s_bdh_mm], ["m1q39s", "m1q4le", "lu8flc", "m1q6td"]]
# [[:s_bdh_mm, :s_bhd_ad], ["lycjnp", "m1q39s", "m1q6td", "m7is3y"]]
# v_bhd_median s_bdh_ad v_bhd_ad s_bdh_md
# v_bdh_ma s_bhd_mm s_bhd_md
# s_bhd_mean v_bdh_median s_bhd_aa v_bhd_aa v_bdh_aa s_bdh_am v_bhd_am v_bhd_ma v_bhd_mm v_bdh_mm

# optimize.call [], %i{ v_bhd_median s_bdh_ad v_bhd_ad s_bdh_md }
# 1.0
# [[:s_bhd_md], ["m1q39s", "m1q4le", "m7iqem", "m7is26", "lu8flc", "m1q6td"]]
# [[:s_bhd_mean, :s_bhd_mm], ["m1q39s", "m1q4le", "m7iqem", "m7is26", "m1q6td", "m7is3y"]]
# [[:s_bhd_mean, :s_bhd_mm], ["lycjnp", "m1q4le", "m7iqem", "m7is26", "m1q6td", "m7is3y"]]
# [[:s_bhd_mean, :s_bhd_mm], ["lycjnp", "m1q39s", "m7iqem", "m7is26", "m1q6td", "m7is3y"]]
# [[:s_bhd_mean, :s_bhd_mm, :s_bhd_md], ["m1q39s", "m1q4le", "m7iqem", "m7is26", "lu8flc", "m1q6td"]]

__END__

require "byebug"
byebug
byebug

