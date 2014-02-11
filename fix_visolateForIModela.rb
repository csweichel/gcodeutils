require 'gcoder'
include GCoder

class Hash
  #pass single or array of keys, which will be removed, returning the remaining hash
  def remove!(*keys)
    keys.each{|key| self.delete(key) }
    self
  end
end

prog = Parser.new.parse File.new(ARGV.first).readlines.join

result = prog.map_with_context do |cmd, ctx|
	# remove stray X,Y or Z
	if (cmd.position rescue []).last == ctx.position.last
		cmd.args.remove!(:Z)
	elsif cmd.is_a? GCode::MotionCommand
		# this is a very convoluted way of comparing the commands position with the context position - something's going terribly wrong here
		cmd.args.remove!(:X, :Y) unless cmd.position.zip(ctx.position).reject {|e| e.include? nil }.map {|e| e.first - e.last }.any? {|e| e > 0.1 }
	end

	# remove stray feedrates
	cmd.args.remove!(:F) if (cmd.feedrate rescue nil) == ctx.feedrate

	# reformat X,Y,Z parameters
	if cmd.is_a? GCode::MoveRapid or cmd.is_a? GCode::MoveByFeedrate
		[:X, :Y, :Z].each_with_index {|c, i| cmd.args[c] = ("%.2f" % cmd.position[i]) unless cmd.args[c].nil? }
	end

	cmd.to_s
end
puts result.first
