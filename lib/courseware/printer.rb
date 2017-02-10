require 'fileutils'
class Courseware::Printer

  def initialize(config, opts)
    @config  = config
    @course  = opts[:course]  or raise 'Course is a required option'
    @prefix  = opts[:prefix]  or raise 'Prefix is a required option'
    @version = opts[:version] or raise 'Version is a required option'
    raise unless can_print?

    @varfile = config[:presfile] or raise 'Presentation file is not set properly!'
    @variant = File.basename(@varfile, '.json') unless @varfile == 'showoff.json'

    @pdfopts = "--pdf-title '#{@course}' --pdf-author '#{@config[:pdf][:author]}' --pdf-subject '#{@config[:pdf][:subject]}'"
    @pdfopts << " --disallow-modify" if @config[:pdf][:protected]

    if @config[:pdf][:watermark]
      showoff          = Courseware.parse_showoff(@config[:presfile])

      @event_id        = showoff['event_id'] || Courseware.question('Enter the Event ID:')
      @password        = showoff['key']      || Courseware.question('Enter desired password:', (@event_id[/-?(\w*)$/, 1] rescue nil))
      @watermark_style = File.join(@config[:cachedir], 'templates', 'watermark.css')
      @watermark_pdf   = File.join(@config[:cachedir], 'templates', 'watermark.pdf')
    end

    FileUtils.mkdir(config[:output]) unless File.directory?(config[:output])

    if block_given?
      yield self
      FileUtils.rm_rf('static')
    end
  end

  def print
    handouts
    exercises
    solutions
  end

  def handouts
    $logger.info "Generating handouts pdf for #{@course} #{@version}..."

    generate_pdf(:print)
  end

  def exercises
    $logger.info "Generating exercise guide pdf for #{@course} #{@version}..."

    generate_pdf(:exercises)
  end

  def solutions
    $logger.info "Generating solutions guide pdf for #{@course} #{@version}..."

    generate_pdf(:solutions)
  end

  def guide
    $logger.info "Generating instructor guide pdf for #{@course} #{@version}..."

    generate_pdf(:guide)
  end

  # Ensure that the printing toolchain is in place.
  def can_print?
    case @config[:renderer]
    when :wkhtmltopdf
      # Fonts must be installed locally for wkhtmltopdf to find them
      if RUBY_PLATFORM =~ /darwin/
        fontpath = File.expand_path('~/Library/Fonts')
        Dir.glob('_fonts/*').each do |font|
          destination = "#{fontpath}/#{File.basename(font)}"
          FileUtils.cp(font, destination) unless File.exists?(destination)
        end
      end

      unless system 'wkhtmltopdf --version >/dev/null 2>&1' and system 'pdftk --version >/dev/null 2>&1'
        msg = "We use wkhtmltopdf and pdftk to generate courseware PDF files.\n" +
              "\n"                                                               +
              "You should install them using Homebrew or directly from:\n"       +
              "  * http://wkhtmltopdf.org/downloads.htm\n"                       +
              "  * https://www.pdflabs.com/tools/pdftk-server/#download"

        unless RUBY_PLATFORM =~ /darwin/
          msg << "\n\n"
          msg << 'Please install all the fonts in the `_fonts` directory to your system.'
        end

        Courseware.dialog('Printing toolchain unavailable.', msg)
        return false
      end

    when :prince
      unless system 'prince --version >/dev/null 2>&1'
        msg = "This course is configured to use PrinceXMLto generate PDF files.\n" +
              "\n"                                                                 +
              "You should install version 9 from:\n"                               +
              "  * http://www.princexml.com/download/\n"                           +
              "\n"                                                                 +
              "And the license from:\n"                                            +
              "  * https://confluence.puppet.com/display/EDU/Licenses"

        Courseware.dialog('Printing toolchain unavailable.', msg)
        return false
      end
    end

    return true
  end

  # clean out the static dir and build the source html
  def generate_html(subject)
    case subject
    when :handouts, :print
      subject = 'print'
    when :exercises, :solutions
      subject = "supplemental #{subject}"
    when :guide
      subject = 'print guide'
    else
      raise "I don't know how to generate HTML of #{subject}."
    end

    begin
      # Until showoff static knows about -f, we have to schlup around files
      if @variant
        FileUtils.mv 'showoff.json', '.showoff.json.tmp'
        FileUtils.cp @varfile, 'showoff.json'
      end

      FileUtils.rm_rf('static')
      system("showoff static #{subject}")
      if File.exists? 'cobrand.png'
        FileUtils.mkdir(File.join('static', 'image'))
        FileUtils.cp('cobrand.png', File.join('static', 'image', 'cobrand.png'))
      end
    ensure
      FileUtils.mv('.showoff.json.tmp', 'showoff.json') if File.exist? '.showoff.json.tmp'
    end
  end

  def generate_pdf(subject)
    # TODO screen printing
    # @pdfopts << " #{SCREENHACK}"
    # @suffix = "-screen"

    # Build the filename for the output PDF. This is ugly.
    output = File.join(@config[:output], "#{@prefix}-")
    output << "#{@variant}-" if @variant
    output << 'w-' if @config[:pdf][:watermark]
    case subject
    when :print
      output << "#{@version}.pdf"
    when :exercises, :solutions, :guide
      output << "#{@version}-#{subject}.pdf"
    else
      raise "I don't know how to generate a PDF of #{subject}."
    end

    generate_html(subject)
    FileUtils.mkdir(@config[:output]) unless File.directory?(@config[:output])

    case @config[:renderer]
    when :wkhtmltopdf
      infofile    = File.join(@config[:output], 'info.txt')
      scratchfile = File.join(@config[:output], 'scratch.pdf')

      command = ['wkhtmltopdf', '-s', 'Letter', '--print-media-type', '--quiet']
      command << ['--footer-left', "#{@course} #{@version}", '--footer-center', '[page]']
      command << ['--footer-right', "©#{Time.now.year} Puppet", '--header-center', '[section]']
      command << ['--title', @course, File.join('static', 'index.html'), output]
      system(*command.flatten)
      raise 'Error generating PDF files' unless $?.success?

      if `pdftk #{output} dump_data | grep NumberOfPages`.chomp == 'NumberOfPages: 1'
        puts "#{output} is empty; aborting and cleaning up."
        FileUtils.rm(output)
        return
      end

      # We can't add metadata in the same run. It requires dumping, modifying, and updating
      if @event_id
        command = ['pdftk', output, 'dump_data', 'output', infofile]
        system(*command.flatten)
        raise 'Error retrieving PDF info' unless $?.success?
        info = File.read(infofile)
        File.open(infofile, 'w+') do |file|
          file.write("InfoBegin\n")
          file.write("InfoKey: Subject\n")
          file.write("InfoValue: #{@event_id}\n")
          file.write(info)
        end
        command = ['pdftk', output, 'update_info', infofile, 'output', scratchfile]
        system(*command.flatten)
        raise 'Error updating PDF info' unless $?.success?
      else
        FileUtils.mv(output, scratchfile)
      end

      command = ['pdftk', scratchfile, 'output', output]
      command << ['owner_pw', @config[:pdf][:password], 'allow', 'printing', 'CopyContents']
      command << ['background', @watermark_pdf] if @config[:pdf][:watermark]
      command << ['user_pw', @password] if @password
      system(*command.flatten)
      raise 'Error watermarking PDF files' unless $?.success?

      FileUtils.rm(infofile)    if File.exists? infofile
      FileUtils.rm(scratchfile) if File.exists? scratchfile

    when :prince
      command = ['prince', File.join('static', 'index.html')]
      command << ['--pdf-title', @course, '--pdf-author', @config[:pdf][:author], '--disallow-modify']
      command << ['--pdf-subject', @event_id] if @event_id
      command << ['--style', @watermark_style] if @config[:pdf][:watermark]
      command << ['--encrypt', '--user-password', @password] if @password
      command << ['--license-file', @config[:pdf][:license]] if (@config[:pdf][:license] and File.exists? @config[:pdf][:license])
      command << ['-o', output]
      system(*command.flatten)
      raise 'Error generating PDF files' unless $?.success?
    end

    FileUtils.rm_rf('static')
  end

end
