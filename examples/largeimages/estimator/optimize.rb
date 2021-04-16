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
  exit if ENV["RANGES"]

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
  sh, fh = {}, {}
  pcbr.table.each do |(f,set), (fm,_), score|
    set.each{ |_| sh[_]||=[] ; sh[_].push [score, fm] }
    f.  each{ |_| fh[_]||=[] ; fh[_].push [score, fm] }
  end
  # sh.each{ |i, a| UnicodePlot.histogram(a, nbins: 10, title: [i, all[i].id].to_s, xlabel: "").render }
  # fh.each{ |i, a| UnicodePlot.histogram(a, nbins: 10, title: i          ,         xlabel: "").render }
  [sh, fh].each do |h|
    pcbr = PCBR.new
    mean = ->(arr){ arr.inject(:+).fdiv arr.size }
    median = ->(arr){ arr.size.odd? ? arr.sort[arr.size/2] : mean[arr.sort[arr.size/2-1,2]] }
    h.each do |i, a|
      pcbr.store i, [-a.size, median[a.transpose[0]], a.transpose[1].max]
    end
    pp pcbr.table.sort_by &:last
  end
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
# [[:s_bhd_md, [-716, -6120.0, 0.3333333333333333], -4],
#  [:v_bhd_ad, [-811, -6053, 0.4444444444444444], -2],
#  [:v_bhd_am, [-352, -6338.0, 0.3333333333333333], -2],
#  [:s_bhd_ma, [-569, -6189, 0.3333333333333333], -2],
#  [:v_bdh_mm, [-694, -6120.0, 0.3333333333333333], -2],
#  [:v_bhd_md, [-86, -6488.0, 0.3333333333333333], -1],
#  [:s_bdh_median, [-5917, -312, 0.75], -1],
#  [:s_bhd_ad, [-5422, -665.0, 0.75], -1],
#  [:s_bdh_mean, [-206, -6411.0, 0.3333333333333333], -1],
#  [:s_bhd_aa, [-451, -6262, 0.3333333333333333], -1],

# optimize.call [], %i{ s_bhd_md s_bhd_ma v_bdh_mm }
# 1.0
# [[:s_bhd_mean, :s_bhd_mm], ["m1q39s", "m1q4le", "m7iqem", "m7is26", "m1q6td", "m7is3y"]]
# [[:s_bhd_mean, :s_bhd_mm], ["lycjnp", "m1q4le", "m7iqem", "m7is26", "m1q6td", "m7is3y"]]
# [[:s_bhd_mean, :s_bhd_mm], ["lycjnp", "m1q39s", "m7iqem", "m7is26", "m1q6td", "m7is3y"]]
# [[5, [-5690, -1011.0, 1.0], -3],
#  [2, [-5893, -945, 1.0], -3],
#  [3, [-5490, -945.0, 0.6666666666666666], -2],
#  [0, [-5055, -1171, 1.0], -1],
#  [4, [-5499, -945, 1.0], 0],
#  [6, [-6637, -582, 0.75], 0],
#  [7, [-6801, -55, 1.0], 0],
#  [1, [-5326, -860.0, 1.0], 3],
#  [8, [-4161, -619, 1.0], 6]]
# [[:s_bdh_median, [-668, -2768.0, 0.3333333333333333], -15],
#  [:v_bdh_aa, [-650, -2768.0, 0.3333333333333333], -13],
#  [:s_bdh_ma, [-631, -2768, 0.3333333333333333], -11],
#  [:v_bdh_am, [-611, -2704, 0.3333333333333333], -7],
#  [:v_bdh_median, [-590, -2704.0, 0.3333333333333333], -5],
#  [:size, [-568, -2704.0, 0.3333333333333333], -3],
#  [:v_bhd_md, [-545, -2704, 0.3333333333333333], -1],
#  [:s_bhd_aa, [-226, -2836.0, 0.3333333333333333], -1],
#  [:s_bhd_mm, [-5879, -860, 1.0], -1],
#  [:width, [-4546, -1181.0, 0.6666666666666666], -1],

# optimize.call [3], %i{ s_bdh_median v_bdh_aa s_bdh_ma v_bdh_am v_bdh_median size v_bhd_md }
# 1.0
# [[:s_bhd_md], ["m1q39s", "m1q4le", "m7iqem", "m7is26", "lu8flc", "m1q6td"]]
# [[:v_bhd_ad, [-400, -3409.0, 0.4444444444444444], -2],
#  [:v_bdh_mm, [-1795, -1858, 0.6666666666666666], -2],
#  [:s_bhd_mean, [-4410, -820.0, 1.0], -2],
#  [:s_bdh_ad, [-331, -3463, 0.4444444444444444], -1],
#  [:s_bhd_median, [-5047, -680, 1.0], -1],

# optimize.call [3], %i{ s_bhd_md s_bhd_ma v_bdh_mm
#                        s_bdh_median v_bdh_aa s_bdh_ma v_bdh_am v_bdh_median size v_bhd_md }
# 1.0
# [[:s_bhd_mean, :s_bhd_am, :s_bhd_mm], ["m1q39s", "m1q4le", "m7iqem", "m7is26", "lu8flc", "m1q6td"]]

Estimator.get_train.push "good/maphbw.jpg"
Estimator.get_fs = [
  [:mean,   false, 50,  true, 0.3,  false, 40, false, 0.000006],
  [:median, false, 120, true, 0.3,  false, 60, false, 0.0005  ],
  [:aa,     false, 40,  true, 0.3,  false, 40, false, 0.000004],
  [:am,     false, 50,  true, 0.3,  false, 50, false, 0.000005],
  [:ma,     false, 50,  true, 0.3,  false, 50, false, 0.000005],
  [:mm,     true,  150, true, 0.3,  false, 70, true,  0.15    ],
  [:ad,     false, 30,  true, 0.3,  false, 30, false, 0.000003],
  [:md,     false, 50,  true, 0.25, false, 40, false, 0.00004 ],
]

# optimize.call
# 0.8
# [[:v_bdh_mean, :s_bhd_aa, :v_bhd_mm, :v_bdh_md], ["m1q39s", "m1q4le", "m7iqem", "lu8flc", "maphbw"]]
# [[:s_bdh_aa, [-526, -5717.0, 0.375], -2],
#  [:s_bhd_ma, [-5058, -579.0, 0.8], -2],
#  [:v_bdh_aa, [-288, -5925.0, 0.375], -2],
#  [:v_bdh_mm, [-4510, -454.0, 0.75], -1],
#  [:s_bdh_mean, [-430, -5780.0, 0.375], -1],
#  [:s_bhd_am, [-666, -5577.0, 0.5625], -1],
#  [:s_bhd_mean, [-781, -5403, 0.5625], -1],
#  [:s_bdh_mm, [-171, -5986, 0.375], -1],
#  [:v_bdh_mean, [-5339, -523, 0.8], -1],
#  [:v_bhd_median, [-361, -5850, 0.375], -1],
#  [:s_bhd_mm, [-4105, -503, 0.6666666666666666], -1],
#  [:v_bhd_am, [-715, -5511, 0.5625], -1],

# optimize.call [], %i{ s_bdh_aa }
# 0.75
# [[:v_bdh_md, [-5093, -593, 0.75], -3],
#  [:s_bhd_aa, [-482, -4537.0, 0.5625], -1],
#  [:s_bdh_md, [-352, -4711.0, 0.375], -1],
#  [:s_bhd_ma, [-794, -2321.0, 0.5625], -1],
#  [:s_bdh_ma, [-206, -5284.0, 0.375], -1],
#  [:v_bhd_median, [-5428, -469.0, 0.75], -1],
#  [:s_bhd_md, [-541, -4468, 0.5625], -1],
#  [:v_bdh_ad, [-716, -4272.0, 0.5625], -1],

# optimize.call [], %i{ s_bdh_md s_bdh_ma }
# 0.75
# [[:s_bhd_median, :v_bhd_median], ["lycjnp", "m1q39s", "m1q4le", "m1q6ub", "m1q6td", "maphbw"]]
# [[:s_bhd_median, :v_bhd_median], ["lycjnp", "m1q39s", "m1q4le", "m1q6ub", "lu8flc", "m1q6td"]]
# [[:s_bdh_mm, [-469, -6165, 0.375], -7],
#  [:v_bhd_aa, [-439, -6165, 0.375], -5],
#  [:v_bdh_am, [-408, -6165.0, 0.375], -3],
#  [:v_bdh_aa, [-238, -6552.0, 0.375], -3],
#  [:height, [-201, -6605, 0.375], -3],
#  [:v_bhd_am, [-274, -6184.0, 0.375], -2],
#  [:s_bhd_ma, [-553, -6041, 0.45], -1],
#  [:v_bdh_mean, [-84, -6781.0, 0.375], -1],
#  [:v_bdh_mm, [-376, -6165.0, 0.375], -1],
#  [:v_bhd_md, [-694, -5814.0, 0.5625], -1],
#  [:v_bhd_mean, [-4438, -814.0, 0.5714285714285714], -1],

Estimator.get_train.push "bad/mb51c0.jpg"
Estimator.get_fs = [
  [:mean,   false, 30,  true, 0.3,  false, 40, false, 0.000005],
  [:median, false, 75,  true, 0.25, false, 60, false, 0.0005  ],
  [:aa,     false, 40,  true, 0.3,  false, 40, false, 0.0000025],
  [:am,     false, 35,  true, 0.3,  false, 50, false, 0.000005],
  [:ma,     false, 40,  true, 0.3,  false, 50, false, 0.000005],
  [:mm,     true,  75,  true, 0.25, false, 70, true,  0.15    ],
  [:ad,     false, 30,  true, 0.3,  false, 35, false, 0.0000025],
  [:md,     false, 40,  true, 0.2, false, 40, false, 0.00004 ],
]

# optimize.call
# 0.6
# [[:s_bhd_aa, :v_bdh_md], ["m1q39s", "lu8flc", "m1q6td"]]
# [[:height, [-931, -4501, 0.5714285714285714], -3],
#  [:s_bdh_am, [-333, -7267, 0.5], -1],
#  [:s_bhd_md, [-406, -7200.0, 0.5], -1],
#  [:v_bdh_median, [-508, -7117.0, 0.5], -1],
#  [:size, [-4551, -1137, 0.6666666666666666], -1],
#  [:s_bhd_median, [-5106, -1010.0, 0.6666666666666666], -1],
#  [:v_bhd_ad, [-175, -7809, 0.375], -1],
#  [:v_bdh_md, [-3706, -1509.0, 0.6666666666666666], -1],
#  [:v_bhd_median, [-846, -4570.0, 0.5714285714285714], -1],

# optimize.call [], %i{ size s_bdh_am s_bhd_md v_bdh_median }
# 0.67
# [[:s_bhd_aa, :v_bdh_md], ["m1q39s", "lu8flc", "m1q6td"]]
# [[:v_bdh_ad, [-4910, -988.0, 0.6666666666666666], -2],
#  [:s_bhd_ma, [-726, -4002.0, 0.5714285714285714], -2],
#  [:v_bhd_ma, [-4000, -1078.0, 0.6666666666666666], -1],
#  [:s_bdh_median, [-4069, -1032, 0.6666666666666666], -1],
#  [:width, [-82, -8158.0, 0.32142857142857145], -1],
#  [:s_bdh_ad, [-232, -7716.0, 0.5], -1],
#  [:s_bdh_md, [-631, -5393, 0.5714285714285714], -1],

# optimize.call [], %i{ v_bdh_ad v_bhd_ma s_bdh_median }
# 0.67
# [[:s_bhd_aa, :v_bdh_md], ["m1q39s", "lu8flc", "m1q6td"]]
# [[:v_bdh_aa, [-4260, -834.0, 0.6666666666666666], -3],
#  [:size, [-4762, -751.0, 0.6666666666666666], -2],
#  [:s_bhd_median, [-343, -5603, 0.45], -1],
#  [:s_bhd_mean, [-579, -5340, 0.5625], -1],
#  [:s_bdh_mean, [-733, -3257, 0.5625], -1],
#  [:s_bhd_am, [-163, -6315, 0.375], -1],
#  [:width, [-84, -6390.0, 0.32142857142857145], -1],

# optimize.call [], %i{ size s_bdh_am s_bhd_md v_bdh_median
#                       v_bdh_ad v_bhd_ma s_bdh_median }
# 0.8
# [[:s_bhd_mean, :v_bdh_md], ["m1q39s", "m1q4le", "lu8flc", "m1q6td"]]

Estimator.get_train.push "bad/map4ed.jpg"
Estimator.get_train.push "good/m8r9g0.jpg"
Estimator.get_train.push "good/m95rpv.jpg"
Estimator.get_fs = [
  [:mean,   false, 30,  true, 0.3,  false, 30, false, 0.000005 ],
  [:median, false, 75,  true, 0.25, false, 60, false, 0.0005   ],
  [:aa,     false, 40,  true, 0.3,  false, 40, false, 0.0000025],
  [:am,     false, 35,  true, 0.3,  false, 50, false, 0.000005 ],
  [:ma,     false, 40,  true, 0.3,  false, 50, false, 0.000005 ],
  [:mm,     true,  75,  true, 0.25, false, 70, true,  0.15     ],
  [:ad,     false, 30,  true, 0.3,  false, 25, false, 0.0000025],
  [:md,     false, 40,  true, 0.2,  false, 40, false, 0.00004  ],
]

# optimize.call
# 0.8571428571428571
# [[:v_bdh_aa, [-4639, -585, 0.8571428571428571], -4],
#  [:v_bdh_md, [-4670, -488.0, 0.8571428571428571], -3],
#  [:s_bhd_am, [-1006, -2948.0, 0.8571428571428571], -1],

# optimize.call [], %i{ v_bdh_aa v_bdh_md s_bhd_am }
# 1.0
# [[:v_bdh_mean, :s_bhd_median, :v_bhd_median, :v_bdh_median, :s_bhd_aa, :s_bdh_aa, :v_bdh_am, :v_bhd_mm, :v_bdh_mm, :s_bhd_md, :v_bhd_md, :size], ["m1q39s", "m1q4le", "m1q6ub", "m7is26", "map4ed", "lu8flc", "m7is3y", "m8r9g0", "m95rpv"]]

Estimator.get_train.push "good/m95on1.jpg"
Estimator.get_fs = [
  [:mean,   false, 30,  true, 0.3,  false, 30, false, 0.000005 ],
  [:median, false, 75,  true, 0.2,  false, 60, false, 0.0002   ],
  [:aa,     false, 40,  true, 0.3,  false, 40, false, 0.0000025],
  [:am,     false, 35,  true, 0.3,  false, 50, false, 0.000005 ],
  [:ma,     false, 40,  true, 0.3,  false, 50, false, 0.000005 ],
  [:mm,     true,  75,  true, 0.25, false, 70, true,  0.15     ],
  [:ad,     false, 30,  true, 0.3,  false, 25, false, 0.0000025],
  [:md,     false, 40,  true, 0.2,  false, 40, false, 0.00004  ],
]

# optimize.call
# 0.78
# [[:v_bdh_md, [-6006, -298.0, 0.7777777777777778], -2],
#  [:height, [-6095, -236, 0.7777777777777778], -2],
#  [:v_bdh_mean, [-2395, -754, 0.7777777777777778], -2],
#  [:v_bhd_mm, [-4360, -337.0, 0.7777777777777778], -1],
#  [:v_bhd_aa, [-365, -4161, 0.5714285714285714], -1],
#  [:v_bhd_ad, [-1418, -1550.0, 0.7777777777777778], -1],
#  [:v_bhd_am, [-3682, -358.0, 0.7777777777777778], -1],

# optimize.call [], %i{ v_bhd_aa }
# 0.8571428571428571
# [[:v_bhd_mean, :v_bdh_mean, :s_bhd_median, :v_bhd_median, :s_bhd_aa, :s_bhd_am, :v_bdh_am, :s_bdh_mm, :v_bdh_mm, :s_bhd_md, :width, :height], ["m1q39s", "m1q4le", "m1q6ub", "map4ed", "m1q6td", "m7is3y", "m8r9g0", "m95on1", "m95rpv"]]
# [[:v_bhd_mean, :v_bdh_mean, :s_bhd_median, :v_bhd_median, :s_bhd_aa, :s_bhd_am, :v_bdh_am, :s_bdh_mm, :v_bdh_mm, :s_bhd_md, :width, :height], ["lycjnp", "m1q39s", "m1q4le", "m1q6ub", "map4ed", "m1q6td", "m7is3y", "m8r9g0", "m95rpv"]]
# [[:s_bdh_md, [-357, -3636, 0.5714285714285714], -5],
#  [:height, [-5930, -353.5, 0.8571428571428571], -2],
#  [:s_bhd_am, [-5364, -366.0, 0.8571428571428571], -2],
#  [:s_bdh_aa, [-316, -3605.0, 0.5714285714285714], -2],
#  [:size, [-511, -3523, 0.6428571428571429], -2],
#  [:v_bhd_ad, [-547, -3461, 0.6428571428571429], -1],
#  [:v_bhd_mm, [-742, -3184.0, 0.7346938775510204], -1],
#  [:s_bdh_ad, [-877, -2245, 0.8571428571428571], -1],
#  [:v_bdh_mean, [-2618, -903.5, 0.8571428571428571], -1],

# optimize.call [], %i{ v_bhd_aa s_bdh_md }
# 0.8571428571428571
# [[:v_bhd_median, :s_bhd_am, :s_bdh_ma, :v_bdh_ma, :v_bdh_mm, :s_bhd_ad, :size], ["m1q39s", "m1q4le", "m7is26", "map4ed", "lu8flc", "m8r9g0", "m95rpv"]]
# [[:v_bhd_median, :s_bhd_am, :s_bdh_ma, :v_bdh_ma, :v_bdh_mm, :s_bhd_ad, :size], ["m1q39s", "m1q4le", "m7is26", "map4ed", "lu8flc", "m7is3y", "m95rpv"]]
# [[:s_bdh_ad, [-1151, -1691, 0.7777777777777778], -8],
#  [:v_bdh_md, [-1229, -1638, 0.7777777777777778], -6],
#  [:v_bhd_ma, [-1211, -1653, 0.7777777777777778], -6],
#  [:s_bdh_median, [-1192, -1660.0, 0.7777777777777778], -6],
#  [:v_bdh_aa, [-1130, -1690.5, 0.7777777777777778], -5],
#  [:v_bdh_mm, [-5000, -1106.0, 0.8571428571428571], -4],
#  [:v_bdh_ma, [-4429, -1300, 0.8571428571428571], -3],
#  [:s_bdh_mean, [-388, -1938.0, 0.5714285714285714], -2],
#  [:v_bdh_am, [-1172, -1638.0, 0.7777777777777778], -2],
#  [:s_bhd_am, [-5628, -526.0, 0.8571428571428571], -2],
#  [:s_bhd_ad, [-6659, -362, 0.8571428571428571], -1],

__END__

Estimator.get_train = %w{
  good/maphbw.jpg
  bad/mb51c0.jpg
  bad/map4ed.jpg
  good/m8r9g0.jpg
  good/m95rpv.jpg
}

optimize.call
