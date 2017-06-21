class Courseware::Composer
  def initialize(config, repository=nil)
    @config     = config
    @repository = repository || Courseware::Repository.new(config)

    return if @config[:presfile] == :none

    if File.exists?(@config[:presfile])
      @showoff    = JSON.parse(File.read(@config[:presfile]))
      @coursename = @showoff['name']
      @prefix     = @showoff['name'].gsub(' ', '_')
    end
  end

  def build(subject)
    courselevel!

    if subject.nil?
      display_tags
      raise "Please re-run this task with a list of tags to include."
    end

    subject.each do |tag|
      key = "tag:#{tag}"
      @showoff['sections'].each do |section|
        raise 'All sections must be represented as Hashes to customize.' unless section.is_a? Hash

        if section.include? key
          raise "A section in showoff.json refers to #{section[key]}, which does not exist." unless File.exist? section[key]
          section['include'] = section[key]
        end
      end
    end

    # normalize the output and trim unused tags
    @showoff['sections'].each do |section|
      section.select! { |k,v| k == 'include' }
    end
    @showoff['sections'].reject! { |section| section.empty? }

    name = Courseware.question('What would you like to call this variant?', 'custom').gsub(/\W+/, '_')
    desc = Courseware.question("Enter a customized description if you'd like:")

    @showoff['description'] = desc if desc

    File.write("#{name}.json", JSON.pretty_generate(@showoff))
    puts "Run your presentation with `showoff serve -f #{name}.json` or `rake present`"
  end

  def package(subject)
    courselevel!
    on_release!
    pristine!

    content   = JSON.parse(`showoff info -jf #{subject}`)
    variant   = File.basename(subject, '.json')
    current   = @repository.current(@coursename)

    if variant == 'showoff'
      output  = @prefix
    else
      output  = "#{@prefix}-#{variant}"
    end

    FileUtils.rm_rf "build/#{@prefix}"
    FileUtils.mkdir_p "build/#{@prefix}"
    FileUtils.cp subject, "build/#{@prefix}/showoff.json"

    # Copy in only the slides used
    content['files'].each do |path|
      FileUtils.mkdir_p "build/#{@prefix}/#{File.dirname(path)}"
      FileUtils.cp path, "build/#{@prefix}/#{path}"
    end

    # Copy in only the images used
    content['images'].each do |path|
      FileUtils.mkdir_p "build/#{@prefix}/#{File.dirname(path)}"
      FileUtils.cp path, "build/#{@prefix}/#{path}"
    end

    # support is special
    FileUtils.cp_r '../_support', "build/#{@prefix}/_support"
    FileUtils.rm_f "build/#{@prefix}/_support/*.pem"
    FileUtils.rm_f "build/#{@prefix}/_support/*.pub"
    FileUtils.rm_f "build/#{@prefix}/_support/aws_credentials"

    # duplicate from cwd to build/variant everything not already copied
    Dir.glob('**{,/*/**}/*').each do |path|
      next if path.start_with? 'build'
      next if path.start_with? 'stats'
      next if path.start_with? 'pdf'
      next if path.start_with? '_images'
      next if path == 'user.js'
      next if path =~ /^\w+.json$/
      next if File.exist? "build/#{@prefix}/#{path}"

      FileUtils.mkdir_p "build/#{@prefix}/#{File.dirname(path)}" unless File.directory?(path)
      FileUtils.ln_s File.expand_path(path), "build/#{@prefix}/#{path}"
    end

    system("tar -C build --dereference -czf build/#{output}-#{current}.tar.gz  #{@prefix}")
    if Courseware.confirm("Would you like to clean up the output build directory?")
      FileUtils.rm_rf "build/#{@prefix}"
    end
  end

private
  def display_tags
    courselevel!

    raise "This course has no tags to choose from." unless @showoff['tags']

    puts
    puts 'Available tags:'
    @showoff['tags'].each do |tag, desc|
      printf " * %-10s: %s\n", tag, desc
    end
    puts
  end

  def courselevel!
    raise 'This task must be run from within a course directory' unless @repository.courselevel?
  end

  def pristine!
    raise 'Your working directory has local modifications or untracked files' unless @repository.clean?
  end

  def on_release!
    count = @repository.outstanding_commits(@prefix)
    unless count == 0
      raise "There have been #{count} commits since release. Either make a release or check out a tagged release."
    end
  end

end