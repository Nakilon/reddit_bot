# $ PLOT=_ cpulimit -i -l 50 ruby optimize.rb

require "pp"

require_relative "common"

optimize = lambda do |exc_set = [], exc_fs = []|
  fs = Estimator.get_fs
  struct = Estimator.struct

  all = Estimator.all
  logs = struct.new *(
    fs.flat_map do |_, *rest|
      rest.each_slice(2).map{ |log, _| log }
    end
  ), false, false, false  # TODO: stop reading keys from this because I can't comment these three out

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
      puts "pcbr.table.size: #{pcbr.table.size}" if pcbr.table.size % 100 == 0
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
    exit if Estimator.class_variable_get(:@@quit)
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

require_relative "train1.rb"

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
