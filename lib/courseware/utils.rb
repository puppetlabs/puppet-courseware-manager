require 'word_wrap'
require 'word_wrap/core_ext'

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

  def self.bailout?(message)
    print "#{message} Continue? [Y/n]: "
    unless [ 'y', 'yes', '' ].include? STDIN.gets.strip.downcase
      if block_given?
        yield
      end
      raise "User cancelled"
    end
  end

  def self.dialog(header, body=nil, width=80)
    width -= 6

    puts '################################################################################'
    puts "## #{header[0..width].center(width)} ##"
    if body
      puts '##----------------------------------------------------------------------------##'
      body.wrap(width).split("\n").each do |line|
        printf "## %-#{width}s ##\n", line
      end
    end
    puts '################################################################################'
  end

  def self.get_component(initial)
    puts 'The component ID for this course can be found at:'
    puts ' * https://tickets.puppetlabs.com/browse/COURSES/?selectedTab=com.atlassian.jira.jira-projects-plugin:components-panel'
    puts
    # grab the number ending the response--either the ID from the URL or the whole string
    question('Please enter the component ID or copy & paste in its URL:', initial)[/(\d*)$/]
  end

  def self.grep(match, filename)
    File.read(filename) =~ Regexp.new(match)
  end

  def self.increment(version, type=:point)
    major, minor, point = version.split('.')
    case type
    when :major
      major.sub!(/^v/, '')  # chop off the v if needed
      "v#{major.to_i + 1}.0.0"

    when :minor
      "#{major}.#{minor.to_i + 1}.0"

    when :point
      "#{major}.#{minor}.#{point.to_i + 1}"

    end
  end

end
