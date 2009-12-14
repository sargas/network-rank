#!/usr/bin/ruby
#This program is free software: you can redistribute it and/or modify
#it under the terms of the GNU General Public License as published by
#the Free Software Foundation, either version 3 of the License, or
#(at your option) any later version.
#
#This program is distributed in the hope that it will be useful,
#but WITHOUT ANY WARRANTY; without even the implied warranty of
#MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#GNU General Public License for more details.
#
#You should have received a copy of the GNU General Public License
#along with this program.  If not, see <http://www.gnu.org/licenses/>.
require 'gnuplot'
require 'optparse'
require 'open-uri'
require 'rbconfig'

#command line processing
options = {}
optparse = OptionParser.new do |opts|
	opts.separator <<eos
	Generates a graph of the SearchIRC ranking scrapped on sahal's server, unless -d is specified.
	Will use default terminal, switching to dumb terminal if DISPLAY is not set and this is not Mac or Windows.
	The options '-s' or '-p' are used to override this. Only one of these options may be used.

eos
	options[:total] = false
	opts.on('-t', '--totals', 'Display total number of networks on same axis.') do
		options[:total] = true
	end
	options[:png] = false
	opts.on('-p', '--png [filename]', 'Outputs as PNG File (defaults to network-rank.png).') do|f|
		options[:png] = f || "network-rank.png"
	end
	options[:svg] = false
	opts.on('-s', '--svg [filename]', 'Outputs as SVG File (defaults to network-rank.svg).') do|f|
		options[:svg] = f || "network-rank.svg"
	end
	options[:data] = "http://sahal.neoturbine.net/~ircd/network-rank"
	opts.on('-d','--data FILE', 'Use FILE (may be a URI) as input.') do|f|
		options[:data] = f
	end
	options[:curve] = "csplines"
	opts.on('-c','--curve CURVETYPE', [:csplines,:bezier,:none],"Smoothing method in use (csplines, bezier, or none). Defaults to csplines.") do|s|
		options[:curve] = (s == :none) ? false : s
	end
	opts.on_tail("-h","--help","Show this message.") do
		puts opts
		exit
	end
end
begin
	optparse.parse!
rescue OptionParser::ParseError => e
	puts e
	puts optparse
	exit 1
end
if options[:svg] and options[:png]
	puts "Please select only one of --svg and --png options."
	puts optparse
	exit 1
end

# plotted variables
x = Array.new
y = Array.new
tot = Array.new

#just needs to be same b/w ruby and gnuplot
timeformat = "%s"

# read data
year = :none #detect year changes
open(options[:data]).each {|line|
	if line =~ /^([0-9]+) out of ([0-9,]+)$/
		#puts "w00t! There is #{$1} out of #{$2}"
		
		#aparently ruby doesn't like to keep these $* around much
		thisrank = $1.to_f
		thistot = $2.gsub(",","").to_f

		# ah, 1 minus since we want the upper percentile
		# times 100 since we are talking percentiles, not proportions
		y.push((1 - thisrank / thistot)*100)
		tot.push(thistot)
	elsif line =~ /^..., (\d\d) (\w\w\w\w?) (\d\d\d\d) (\d\d):(\d\d):(\d\d)/
		#puts "On month #{$2}, day #{$1} of year #{$3}"
		#time is $4 hours past midnight, $5 minutes, $6 seconds
		x.push(Time.local($3,$2,$1,$4,$5,$6).strftime(timeformat))
		year = case year
			when :none then $3
			when :diff then :diff
			when $3 then $3
			else :diff
		end
	end
}
puts x

Gnuplot.open do |gp|
	Gnuplot::Plot.new(gp) do |plot|
		plot.title "Neoturbine.NET Network Rating"
		plot.ylabel "Percentile"
		plot.xlabel "Date"

		plot.xdata "time"
		# need escaped quotes since gnuplot wants its own quotes
		plot.timefmt "\"" + timeformat +"\""
		if year == :diff
			plot.format "x \"%b\\n%d\\n%Y\""
		else
			plot.format "x \"%m/%y\""
		end
		plot.key "left top"

		if options[:total]
			plot.ytics "nomirror"
			plot.y2label "\"Number Of Networks\""
			plot.y2tics
		end

		if options[:png]
			plot.terminal "png"
			plot.output options[:png]
		elsif options[:svg]
			plot.terminal "svg"
			plot.output options[:svg]
		elsif (Config::CONFIG['host_os'].downcase =~ /mswin|mingw|darwin|mac/) or ENV['DISPLAY'].nil?
			plot.terminal "dumb"
		end

		datasets = [
			# data points themselves...
			Gnuplot::DataSet.new([x,y]) { |ds|
				ds.with = "points lt rgb \"coral\""
				ds.using = "1:2"
				ds.notitle
			# curve connecting them
			# probably doesn't look good till we have more data
			}, Gnuplot::DataSet.new([x,y]) { |ds|
				ds.with = "lines lt rgb \"dark-turquoise\""
				ds.using = "1:2" + (options[:curve]? " smooth "+options[:curve].to_s: "")
				ds.notitle unless options[:total]
				ds.title = "IRC Ranking" if options[:total]
			}
		]
		datasets.push(Gnuplot::DataSet.new([x,tot]) { |ds|
				ds.with = "linespoints lt rgb \"blue\""
				ds.using = "1:2 axis x1y2"
				ds.title = "Total # of IRC Networks"
			}
		) if options[:total]
		plot.data = datasets
	end
end
