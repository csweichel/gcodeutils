#!/usr/bin/ruby

if ARGV.length < 1
	puts "usage: #{__FILE__} <infile> [<outfile>]"
	exit
end

CMD_WHITELIST = %w{G1 G90 G21}

def nn(res, val)
	val.nil? ? res : yield(val)
end

result = File.new(ARGV.first).readlines 		\
	.map {|line| line.strip }					\
	.map {|line| line.gsub("G0", "G1") }		\
	.select {|line| CMD_WHITELIST.any? {|cmd| line.include?("#{cmd} ") } or line[0..0] == "(" } \
	.map {|line| nn(line, /F(\d+(\.\d+)?)/.match(line)) {|vals| "G1 F#{vals[1]}" } } \
	.map {|line| nn(line, /([^\(]*)\(([^\)]*)\)/.match(line)) {|vals| "#{vals[1]} ; #{vals[2]}" } } \
	.map {|line| nn(line, /^[A-Z]/.match(line)) { line.scan(/[A-Z]/).zip(line.split(/[A-Z]/)[1..-1]).map {|e| "#{e.first.strip}#{e.last.strip}" }.join(" ") } } \
	.map {|line| line.strip }

if ARGV.length > 1
	File.open(ARGV[1], "w") {|f| f.puts result }
else
	puts result
end
