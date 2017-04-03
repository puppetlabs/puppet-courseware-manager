class Courseware::Manager

  def obsolete
    # We need to get all slides from all variants to determine what's obsolete.
    allsections = Dir.glob('*.json').collect do |variant|
      Courseware.parse_showoff(variant)['sections'] rescue nil
    end.flatten.uniq

    puts "Obsolete images:"
    Dir.glob('**/_images/*') do |file|
      next if File.symlink? file
      next if File.directory? file
      next if system("grep #{file} *.css */*.md >/dev/null 2>&1")

      puts "  * #{file}"
      @warnings += 1
    end

    puts "Obsolete slides:"
    Dir.glob('**/*.md') do |file|
      next if File.symlink? file
      next if File.directory? file
      next if file =~ /^_.*$|^[^\/]*$/
      next if allsections.include? file

      puts "  * #{file}"
      @warnings += 1
    end
  end

  def missing
    sections = @sections.dup

    # This seems backwards, but we do it this way to get a case sensitive match
    # http://stackoverflow.com/questions/357754/can-i-traverse-symlinked-directories-in-ruby-with-a-glob -- Baby jesus is crying.
    Dir.glob("**{,/*/**}/*.md") do |file|
      sections.delete(file)
    end
    return if sections.empty?

    puts "Missing slides:"
    sections.each do |slide|
      puts "  * #{slide}"
      @errors += 1
    end
  end

  def lint
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