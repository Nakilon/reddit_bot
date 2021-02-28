require "yaml"
raw = YAML.load(STDIN.read)

fs = [
  [:mean1,   true, 0.5   ], [:mean2,   false, 20],
  [:median1, true, 0.15  ], [:median2, false, 35],
  [:aa1,     true, 0.5   ], [:aa2,     false, 20],
  [:am1,     true, 0.6   ], [:am2,     false, 25],
  [:ma1,     true, 0.5   ], [:ma2,     false, 25],
  [:mm1,     true, 0.15  ], [:mm2,     false, 40],
  [:ad1,     true, 0.5   ], [:ad2,     false, 15],
  [:md1,    false, 0.0001], [:md2,     false, 25],
]
struct = Struct.new :id, :cls, *fs.map(&:first)
all = raw.map do |id, cls, *rest|
  # normalize = ->(arr){ arr.map{ |_| (_ - arr.min) / (arr.max - arr.min) * (Math::E - 1) + 1 } }
  struct.new id.split(".")[0], cls.to_sym, *rest.zip(fs).map{ |v, (f, log, r)| (log ? Math::log(v+1) : v) * r }
end

fs.each do |f, log,|
  min, max = all.map(&f).minmax
  puts "#{f}#{" (log)" if log}: #{(max - min).round 3}"
  if ENV["PLOT"]
    require "unicode_plot"
    require "io/console"
    UnicodePlot.lineplot(all.size.times.to_a, all.map(&f).sort, labels: false, width: IO.console.winsize[1]-7).render
  end
end
exit if ENV["PLOT"]

require "pp"
require "set"
require "pcbr"
ds = struct.new nil, nil, *(fs.map do |g,|
  all.size.times.map do |i|
    all.size.times.map do |j|
      (all[i][g] - all[j][g]) * (all[i][g] - all[j][g])
    end
  end
end)
pcbr = PCBR.new
pcbr_set = Set.new
best = nil
prev_time = nil
combinations = [
  [fs.map(&:first), all.size.times.to_a],
]
loop do
  combinations.each do |f, set|
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
            f.sum{ |g| ds[g][i][j] }
          }
        ].cls,
      ] ]
    end
    tp = t.count :tp
    d = (tp + t.count(:fp)) * (tp + t.count(:fn))
    pcbr.store [f, set], [
      d.zero? ? 0 : Math::sqrt((tp * tp).fdiv(d)),
      -f.size, -set.size
    ]
    p pcbr.table.size if pcbr.table.size % 100 == 0
  end
  if best != t = pcbr.table.max_by{ |_,(fm,_),| fm }.tap{ |(f,set),(fm,_),| break [f, set, fm] }
    best, prev_time = t, Time.now
    p best
  end
  combinations = pcbr.table.sort_by{ |_, _, score| -score }.lazy.map do |(f, set), *|
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
  abort "TODO" unless combinations
  break if Time.now - prev_time > 5
end
pcbr.table.sort_by{ |_,(fm,_),| -fm }.take(25).map{ |(f,set),(fm,_),| break [f, all.values_at(*set).map(&:id), fm] }.tap &method(:p)

__END__

$ cpulimit -i -l 50 ruby main.rb < all.yaml

[[:am1, :ma2, :mm2, :md2], ["lbe98z", "libau8", "lkx0o8", "lot2c8", "luc2ff", "lavctb", "lbznk0", "lletah", "lou78u"], 0.8559209850218258]
