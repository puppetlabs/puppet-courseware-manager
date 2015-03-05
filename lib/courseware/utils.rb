class Courseware
  def self.question(message, default=nil)
    if default
      print "#{message} [#{default}] "
    else
      print "#{message} "
    end

    answer = STDIN.gets.strip

    return answer.empty? ? default : answer
  end

  def self.confirm(message)
    print "#{message} [Y/n]: "
    [ 'y', 'yes', '' ].include? STDIN.gets.strip.downcase
  end

  def self.provide_bailout(message)
    print "#{message} Continue? [Y/n]: "
    raise "User cancelled" unless [ 'y', 'yes', '' ].include? STDIN.gets.strip.downcase
  end

  def self.grep(match, filename, warning="String '#{match}' not found in #{filename}")
    raise warning unless File.read(filename) =~ Regexp.new(match)
  end

end
