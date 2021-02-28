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

require "vips"
require "yaml/store"
all = %w{ good bad }.flat_map do |what|
  YAML::Store.new("store.yaml").transaction(!!ARGV[0]) do |store|
    Dir.glob("#{what}/*").sort.map.with_index do |file, i|
      bw = Vips::Image.new_from_file(file).colourspace("b-w").flatten
      diff = ->{ (bw.hist_find - bw.+(0).gaussblur(1).hist_find).abs / bw.hist_find.max }
      hist_filename = File.basename file
      STDERR.puts "#{what} (#{i+1}/#{Dir.glob("#{what}/*").size}): #{hist_filename}"
      # unless File.exist? hist_filename
      #   diff.call.*(256).floor.hist_plot.write_to_file hist_filename
      # end
      hists = if store.root? file
        store.fetch file
      else
        store[file] = [
          (bw - bw.+(0).gaussblur(1)).abs.*(10).hist_find.to_a.flatten,
          diff.call.to_a.flatten,
        ]
      end
      [what, hist_filename, hists]
    end
  end
end.map do |cls, id, hists|
  STDERR.puts id
  [id, cls, *[mean, median, aa, am, ma, mm, ad, md].flat_map{ |f| hists.map &f }]
end

puts YAML.dump all

__END__

$ cpulimit -i -l 50 ruby all.rb > all.yaml
