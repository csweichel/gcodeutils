#!/usr/bin/ruby
require 'optparse'

options = {}
optparse = OptionParser.new do|opts|
  opts.banner = "Usage: #{__FILE__} [options] drillfile.drd outfile.gcode"

  options[:start] = [0, 0]
  opts.on( '-s', '--start STARTPOINT', 'The start point of the printer, format [XX]x[YY] [mm]' ) do |start|
    options[:start] = start.split("x").map {|p| p.to_f }
  end

  options[:first] = [0, 0]
  opts.on( '-f', '--first FIRSTPOINT', 'First drill point to go for and equate to zero, format [XX]x[YY] [mm]' ) do |first|
    options[:first] = first.split("x").map {|p| p.to_f }
  end

  options[:milToMM] = false
  opts.on( '-m', '--mil2mm', 'Translate units from MIL to MM' ) do
    options[:milToMM] = true
  end   

  options[:invertX] = false
  opts.on( '-iX', '--invert-x', 'Inverts the x axis' ) do
    options[:invertX] = true
  end

  options[:travelHeight] = 5
  opts.on( '-t', '--travel-height HEIGHT', 'The travel height in mm' ) do |height|
    options[:travelHeight] = height
  end

  options[:drillHeight] = 0
  opts.on( '-d', '--drill-height HEIGHT', 'The drill height in mm' ) do |height|
    options[:drillHeight] = height
  end

  options[:rotate] = 0
  opts.on( '-r', '--rotate ANGLE', 'Rotates the holes by ANGLE degrees' ) do |angle|
    options[:rotate] = angle.to_f * (Math::PI / 180.0)
  end

  options[:preamble] = "G90\nG1 F1500\n"
  opts.on( '-pa', '--preamble FILE', 'Prepend the preamble from FILE' ) do |f|
    options[:preamble] = File.new(f).readlines.join
  end

  options[:postamble] = ""
  opts.on( '-po', '--postamble FILE', 'Append the postamble from FILE' ) do |f|
    options[:postamble] = File.new(f).readlines.join
  end

  options[:verbose] = false
  opts.on( '-v', '--verbose', 'Produce verbose output' ) do
    options[:verbose] = true
  end

  options[:gnuplot] = false
  opts.on( '-g', '--gnuplot', 'Plot the drill holes on the console' ) do
    options[:gnuplot] = true
  end

  opts.on( '-h', '--help', 'Display this screen' ) do
    puts opts
    exit
  end
end
optparse.parse!

if ARGV.length < 2 then
   puts optparse
   exit 
end


I = options[:first]
S = options[:start]

IN_FILE = ARGV[0]
OUT_FILE = ARGV[1]

# reading excellon file
excellon = File.new(IN_FILE).readlines
holes = excellon.select {|l| l.include?("X") }.map {|p| p.gsub("X", "").split("Y").map {|e| e.to_f } }

# mill to mm
holes = holes.map {|p| p.map {|e| e * 0.00254 } } if options[:milToMM]

# verbose
puts "holes read:\n#{holes.map {|s| s.join("x") }.join("\t")}\n" if options[:verbose]

# first point
ghles = holes.map {|p| [p[0] - I[0], p[1] - I[1]] }

# rotate
ghles = holes.map {|p| 
    sin = Math::sin(options[:rotate])
    cos = Math::cos(options[:rotate])

    [p[0] * cos - p[1] * sin, p[0] * sin + p[1] * cos]
} if options[:rotate] != 0

# machine start
ghles = ghles.map {|p| [p[0] + S[0], p[1] + S[1]] }

# invert X
ghles = ghles.map {|p| x,y = p; [S[0] - (x - S[0]), y] } if options[:invertX]

# verbose
puts "\ndrilling at:\n#{ghles.map {|s| s.join("x") }.join("\t")}\n" if options[:verbose]

# gcode generation
gcode = ghles.map {|p| x,y = p; [ "G1 Z#{options[:travelHeight]}", "G1 X#{x} Y#{y}", "G1 Z#{options[:drillHeight]}" ] }

File.open(OUT_FILE, "w") {|f| 
  f.puts "; generated by #{__FILE__} from #{IN_FILE} at #{Time.now()}"
  f.puts
  f.puts options.map {|o|
    "; #{o.first}: #{(o.last.is_a?(Array) ? o.last.join(" ") : o.last.to_s).gsub("\n", " ")}"
  }.join("\n")
  f.puts
  f.puts options[:preamble]
  f.puts gcode
  f.puts "G1 Z#{options[:travelHeight]}"
  f.puts options[:postamble]
  f.puts
}

# gnuplot
if options[:gnuplot]
  max = ghles.flatten.max * 1.1
  IO.popen("gnuplot -persist -e 'set size ratio 1; set xrange [0:#{max}]; set yrange [0:#{max}]; set label 1 \"\" at #{ghles.first[0]},#{ghles.first[1]} point pointtype 2; plot \"-\" u 1:2 w points notitle'", 'r+'){|n| 
    n.print ghles.map {|p| p.join(" ") }.join("\n")
  }
end