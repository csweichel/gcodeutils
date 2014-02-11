#!/usr/bin/ruby

require 'gcoder'
include GCoder

if ARGV.length < 4
	puts "usage: #{__FILE__} <infile> <travelZ> <targetZ> <zStep> [<outfile>]"
	exit
end

infile, travelZ, targetZ, zStep = ARGV

prog = Parser.new.parse File.new(infile).readlines.join

TRAVEL_HEIGHT = travelZ.to_f
CUTTING_HEIGHT = targetZ.to_f
STEP_HEIGHT = zStep.to_f

# identify milling section
milling_section_mark = prog.map_with_context do |cmd, ctx|
	if cmd.is_a? GCode::MoveRapid and cmd.position[2] == TRAVEL_HEIGHT
		ctx[:sec] = :rapid
	elsif cmd.is_a? GCode::MoveByFeedrate
		ctx[:sec] = :feed
	elsif cmd.is_a? GCode::MoveRapid and ctx[:sec] == :feed
		ctx[:sec] = nil
	end

	ctx[:sec] ? true : false
end.first
milling_section = prog.zip(milling_section_mark).select {|cmd, mark| mark }.map {|cmd, mark| cmd }

# replicate section to create rounds
milling_prog = (1..(CUTTING_HEIGHT / STEP_HEIGHT).abs.ceil).to_a.map do |s|
	depth = (CUTTING_HEIGHT < 0 ? -1 : 1) * s * STEP_HEIGHT
	milling_section.map do |cmd| 
		if cmd.position.last == CUTTING_HEIGHT and cmd.is_a? GCode::MoveByFeedrate
			GCode::MoveByFeedrate.new(cmd.code, { :Z => depth, :F => cmd.feedrate })
		else
			cmd
		end
	end
end.flatten

# replace original section with new milling program
result = prog.zip(milling_section_mark).each_with_object({:repl => false}).map do |cmdAndMark, state|
	if cmdAndMark.last and not state[:repl]
		state[:repl] = true
		milling_prog
	elsif not cmdAndMark.last
		cmdAndMark.first
	end
end

# output it all
out = result.flatten.compact.join("\n")
if ARGV.length > 4
	File.open(ARGV.last, "w") {|f| f.puts out }
else
	puts out
end
