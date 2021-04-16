require "pp"

require_relative "common"
require_relative "train1.rb"
Estimator.get_train.push "good/maphbw.jpg"
fs, set = [:s_bhd_md], ["m1q39s", "m1q4le", "m7iqem", "m7is26", "lu8flc", "m1q6td"]

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
fs, set = [:v_bdh_mean, :s_bhd_aa, :v_bhd_mm, :v_bdh_md], ["m1q39s", "m1q4le", "m7iqem", "lu8flc", "maphbw"]

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
fs, set = [:s_bhd_mean, :v_bdh_md], ["m1q39s", "m1q4le", "lu8flc", "m1q6td"]

Estimator.get_train.push "bad/map4ed.jpg"
Estimator.get_train.push "good/m8r9g0.jpg"
Estimator.get_train.push "good/m95rpv.jpg"

# Estimator.get_train = %w{
#   good/maphbw.jpg
#   bad/mb51c0.jpg
#   bad/map4ed.jpg
#   good/m8r9g0.jpg
#   good/m95rpv.jpg
# }
fs, set = [:v_bdh_mean, :s_bhd_median, :v_bhd_median, :v_bdh_median, :s_bhd_aa, :s_bdh_aa, :v_bdh_am, :v_bhd_mm, :v_bdh_mm, :s_bhd_md, :v_bhd_md, :size], ["m1q39s", "m1q4le", "m1q6ub", "m7is26", "map4ed", "lu8flc", "m7is3y", "m8r9g0", "m95rpv"]

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
fs, set = [:v_bhd_median, :s_bhd_am, :s_bdh_ma, :v_bdh_ma, :v_bdh_mm, :s_bhd_ad, :size],
          ["m1q39s", "m1q4le", "m7is26", "map4ed", "lu8flc", "m8r9g0", "m95rpv"]
fs, set = [:v_bhd_median, :s_bhd_am, :s_bdh_ma, :v_bdh_ma, :v_bdh_mm, :s_bhd_ad, :size],
          ["m1q39s", "m1q4le", "m7is26", "map4ed", "lu8flc", "m7is3y", "m95rpv"]
remaining_for_tests = [
  "good/m1q6td.jpg",
  "bad/m1q6ub.jpg",
  "bad/m7iqem.jpg",
  "bad/lycjnp.jpg",
  "good/maphbw.jpg",
  "bad/mb51c0.jpg",
  "good/m8r9g0.jpg",
  "good/m95on1.jpg",
]

all = Estimator.all.select{ |i| set.include? i.id }

(remaining_for_tests + %w{
  bad/mayslu.jpg
  bad/masgbn.jpg
  bad/majgeq.jpg
  bad/mba599.jpg
  good/m8lvjk.jpg
  good/m97q41.jpg
}).each do |file|
  a = Estimator.analyze file
  best = all.min_by{ |b| fs.sum{ |f| (a[f] - b[f]) * (a[f] - b[f]) } }
  p [a.id, a.cls, best.id, best.cls]
end
