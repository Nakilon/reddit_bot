require_relative "common"

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
Estimator.get_train = %w{
  bad/m1q39s.jpg
  bad/m1q4le.jpg
  bad/m7is26.jpg
  bad/map4ed.jpg
  good/lu8flc.jpg
  good/m7is3y.jpg
  good/m95rpv.jpg
}

fs, set = [:v_bhd_median, :s_bhd_am, :s_bdh_ma, :v_bdh_ma, :v_bdh_mm, :s_bhd_ad, :size],
          ["m1q39s", "m1q4le", "m7is26", "map4ed", "lu8flc", "m7is3y", "m95rpv"]


# all = Estimator.all.select{ |i| set.include? i.id }

require "yaml"
all = YAML.load_file "all.yaml"

# url = "http://www.nakilon.pro/mazebg.png"


require "functions_framework"
FunctionsFramework.http "estimator" do |request|
  url = Base64::strict_decode64(request.body.read).force_encoding("utf-8")
  system "curl -s '#{url}' -o temp --retry 5" or fail
  a = Estimator.analyze "temp", true
  best = all.min_by{ |b| fs.sum{ |f| (a[f] - b[f]) * (a[f] - b[f]) } }
  [best.id, best.cls].inspect
end
