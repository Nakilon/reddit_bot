require "pp"

require_relative "common"
require_relative "train1.rb"

fs, set = [:s_bhd_md], ["m1q39s", "m1q4le", "m7iqem", "m7is26", "lu8flc", "m1q6td"]

%w{
  bad/mayslu.jpg
  bad/masgbn.jpg
  good/maphbw.jpg
  bad/map4ed.jpg
  bad/majgeq.jpg
  bad/mb51c0.jpg
  bad/mba599.jpg
}.each do |file|
  a = Estimator.analyze file
  best = Estimator.all.select{ |i| set.include? i.id }.min_by{ |b| fs.sum{ |f| (a[f] - b[f]) * (a[f] - b[f]) } }
  p [best.id, a.cls, best.cls]
end
