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
    raise "User cancelled" unless [ 'y', 'yes', '' ].include? STDIN.gets.strip.downcase
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

  def self.increment(version)
    pemajor, major, minor = version.split('.')
    "#{pemajor}.#{major}.#{minor.to_i + 1}"
  end

  def self.majversion(version)
    pemajor, major, minor = version.split('.')
    "#{pemajor}.#{major.to_i + 1}.0"
  end

end
