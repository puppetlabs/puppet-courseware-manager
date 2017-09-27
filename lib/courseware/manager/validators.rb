class Courseware::Manager

  def obsolete
    toplevel!

    allslides = Dir.glob('_content/**/*.md')
    allimages = Dir.glob('_images/**/*').reject {|path| path.include? '_images/src' }
    slides    = []
    images    = []

    Dir.glob('*').each do |path|
      next if path == 'spec'
      next if path == 'stats'      
      next if path.start_with? '_'
      next unless File.directory? path

      print "Validating #{path}."

      # stuff presentation local slides & images into the collections of available content
      allslides.concat Dir.glob("#{path}/**/*.md").reject {|file| file.include?('README.md')      ||
                                                                  file.include?('_notes')         ||
                                                                  File.dirname(file) == path }

      allimages.concat Dir.glob("#{path}/_images/**/*").reject {|file| file.include?('README.md') ||
                                                                       file.include?('src/')      ||
                                                                       File.directory?(file) }

      Dir.chdir(path) do
        Dir.glob('*.json').each do |filename|
          # determine which slides and images are actually used
          content = JSON.parse(`showoff info -jf #{filename}`)
          lslides = content['files'].map do |slide|
            slide.start_with?('_') ? slide.sub('_shared', '_content') : "#{path}/#{slide}"
          end
          limages = content['images'].map do |image|
            image.start_with?('_images/shared') ? image.sub('_images/shared', '_images') : "#{path}/#{image}"
          end

          slides.concat(lslides)
          images.concat(limages)

          print '.'
        end
        puts
      end
    end

    # remove the intersection, and what's left over is obsolete
    obs_slides = (allslides - slides.uniq!)
    obs_images = (allimages - images.uniq!)

    puts "Obsolete slides:" unless obs_slides.empty?
    obs_slides.each do |slide|
      puts "  * #{slide}"
      @warnings += 1
    end

    puts "Obsolete images:" unless obs_images.empty?
    obs_images.each do |image|
      puts "  * #{image}"
      @warnings += 1
    end
  end

  def missing
    courselevel!

    filename = @config[:presfile]
    content  = JSON.parse(`showoff info -jf #{filename}`)
    sections = content['files']
    images   = content['images']

    # This seems backwards, but we do it this way to get a case sensitive match on a case-insensitive-preserving filesystem
    # http://stackoverflow.com/questions/357754/can-i-traverse-symlinked-directories-in-ruby-with-a-glob -- Baby jesus is crying.
    Dir.glob("**{,/*/**}/*.md") do |file|
      sections.delete(file)
    end
    Dir.glob("_images/**{,/*/**}/*") do |file|
      images.delete(file)
    end

    puts "Missing slides:" unless sections.empty?
    sections.each do |slide|
      puts "  * #{slide}"
      @errors += 1
    end

    puts "Missing images:" unless images.empty?
    images.each do |slide|
      puts "  * #{slide}"
      @errors += 1
    end
  end

  def lint
    courselevel!

    puts "Checking Markdown style:"
    style  = File.join(@config[:cachedir], 'templates', 'markdown_style.rb')
    style  = File.exists?(style) ? style : 'all'
    issues = 0

    unless system('mdl', '--version')
      puts '  * Markdown linter not found: gem install mdl'
      puts
      @warnings += 1
      return
    end

    Dir.glob('**/*.md') do |file|
      next if File.symlink? file
      next if File.directory? file
      next if file =~ /^_.*$|^[^\/]*$/

      issues += 1 unless system('mdl', '-s', style, file)
    end

    if issues > 0
      puts
      puts 'Rule explanations can be found at:'
      puts '  * https://github.com/mivok/markdownlint/blob/master/docs/RULES.md'
      puts
      @warnings += issues
    end
  end

end