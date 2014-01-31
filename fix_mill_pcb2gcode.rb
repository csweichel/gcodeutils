#!/usr/bin/ruby

if ARGV.length < 4
	puts "usage: #{__FILE__} <infile> <originalZ> <targetZ> <zStep> [<outfile>]"
	exit
end

$stderr.puts """
BE AWARE: This script can only handle continuous milling paths. Any non-
continuous path will be milled as if it was continuous, meaning that any
gap in the path will be ignored.

THIS CAN DESTROY YOUR BOARD.
Be sure to check the resulting gCode before using it.
"""

infile, originalZ, targetZ, zStep = ARGV
targetZ = targetZ.to_f
zStep = zStep.to_f

script = File.new(infile).readlines
	.map {|line| line.strip }

block = script.inject([false, []]) do |m,e|
	in_block, result = m
	
	cmd,*args = e.split(" ")
	in_block = true if cmd == "G01" and args.first == "Z#{originalZ}"
	if in_block
		if cmd == "G00"
			in_block = false
		else
			result << e
		end
	end

	[ in_block, result ]
end.last

if block.empty? 
	candidates = script.select {|r| cmd,*args=r.split(" "); cmd == "G01" and args.first[0...1] == "Z"}.map {|r| r.split(" ")[1][1..-1] }
	puts "No milling block found. Make sure originalZ is correct (was set to #{originalZ}, candidates are #{candidates.join(" ")})"
	exit
end
 	
replacement = (1..(targetZ / zStep).ceil.abs).map do |i|
	depth = (targetZ < 0 ? -1 : 1) * zStep * i
	["(begin mill)"] + block.map {|r| r.gsub("Z#{originalZ}", "Z#{depth}") }
end.flatten

result = script.join("\n").gsub(block.join("\n"), replacement.join("\n"))

if ARGV.length > 4
	File.open(ARGV.last, "w") {|f| f.puts result }
else
	puts result
end
