#!/usr/bin/ruby
require 'gnuplot'
require 'optparse'

#command line processing
options = {}
optparse = OptionParser.new do |opts|
	opts.banner = "Usage: network-rank.rb [options]"
	opts.separator <<eos
	Generates a graph of the data found in 'network-rank' file.
	Outputs to default gnuplot terminal (usually X11?) unless the '-p' option is specified
eos
	options[:total] = false
	opts.on('-t', '--totals', 'Display Total Number of Networks on Same Axis') do
		options[:total] = true
	end
	options[:png] = false
	opts.on('-p', '--png [filename]', 'Outputs as PNG File (defaults to network-rank.png)') do|f|
		options[:png] = f || "network-rank.png"
	end
	options[:data] = "network-rank"
	opts.on('-d','--data FILE', 'Use FILE instead of ./network-rank as input') do|f|
		options[:data] = f
	end
	opts.on_tail("-h","--help","Show this message") do
		puts opts
		exit
	end
end
optparse.parse!

# plotted variables
x = Array.new
y = Array.new
tot = Array.new

# read data
source = File.new(options[:data])
while line = source.gets
	if line =~ /^([0-9]+) out of ([0-9,]+)$/
		#puts "w00t! There is #{$1} out of #{$2}"
		
		#aparently ruby doesn't like to keep these $* around much
		thisrank = $1.to_f
		thistot = $2.gsub(",","").to_f

		# ah, 1 minus since we want the upper percentile
		# times 100 since we are talking percentiles, not proportions
		y.push((1 - thisrank / thistot)*100)
		tot.push(thistot)
	elsif line =~ /^..., (\d\d) (\w\w\w\w?) (\d\d\d\d)/
		#puts "On month #{$2}, day #{$1} of year #{$3}"
		x.push(Time.local($3,$2,$1).strftime("%Y-%m-%d"))
	end
end

Gnuplot.open do |gp|
	Gnuplot::Plot.new(gp) do |plot|
		plot.title "Neoturbine.NET Network Rating"
		plot.ylabel "Percentile"
		plot.xlabel "Date"

		plot.xdata "time"
		# need escaped quotes since gnuplot wants its own quotes
		plot.timefmt "\"%Y-%m-%d\""
		plot.format "x \"%m/%d\""
		plot.key "left top"

		if options[:total]
			plot.ytics "nomirror"
			plot.y2label "\"Number Of Networks\""
			plot.y2tics
		end

		if options[:png]
			plot.terminal "png"
			plot.output options[:png]
		end
	    
		datasets = [
			# data points themselves...
			Gnuplot::DataSet.new([x,y]) { |ds|
				ds.with = "points"
				ds.using = "1:2"
				ds.notitle
			# smoothened curve connecting them
			# probably doesn't look good till we have more data
			}, Gnuplot::DataSet.new([x,y]) { |ds|
				ds.with = "lines"
				ds.using = "1:2 smooth csplines"
				ds.notitle unless options[:total]
				ds.title = "IRC Ranking" if options[:total]
			}
		]
		datasets.push(Gnuplot::DataSet.new([x,tot]) { |ds|
				ds.with = "linespoints"
				ds.using = "1:2 axis x1y2"
				ds.title = "Total # of IRC Networks"
			}
		) if options[:total]
		plot.data = datasets
	end
end
