class Courseware::Manager

  def obsolete
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
      next if @sections.include? file

      puts "  * #{file}"
      @warnings += 1
    end
  end

  def missing
    sections = @sections.dup

    # This seems backwards, but we do it this way to get a case senstive match
    Dir.glob('**/*.md') do |file|
      next if File.symlink? file
      next if File.directory? file
      next if file =~ /^_.*$|^[^\/]*$/
      sections.delete(file)
    end
    return if sections.empty?

    puts "Missing slides:"
    sections.each do |slide|
      puts "  * #{slide}"
      @errors += 1
    end
  end

  def style
    puts "Checking Markdown style:"
    style  = File.join(@config[:cachedir], 'templates', 'markdown_style.rb')
    style  = File.exists?(style) ? style : 'all'
    issues = 0

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