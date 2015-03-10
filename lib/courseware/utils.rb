require 'word_wrap'

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

  def self.increment(version, quarterly=false)
    pemajor, major, minor = version.split('.')
    if quarterly
      "#{pemajor}.#{major.to_i + 1}.0"
    else
      "#{pemajor}.#{major}.#{minor.to_i + 1}"
    end
  end

  def self.release_notes_table(version)
    updated  = []
    outdated = []
    missing  = []
    Dir.glob('*').select do |course|
      next unless File.directory? course
      next if course =~ /^_/

      notes = "#{course}/Release-Notes.md"
      case
      when ! File.exist?(notes)
        missing << course
      when Courseware.grep(version, notes)
        updated << course
      else
        outdated << course
      end
    end

    n = 0
    puts
    puts "  Updated Release Notes    Outdated Release Notes    Missing Release Notes"
    puts "----------------------------------------------------------------------------"
    [ updated.size, outdated.size, missing.size ].max.times do
      printf "  %20s    %20s    %20s\n", updated[n], outdated[n], missing[n]

      n += 1
    end
    puts
  end
end
