require 'fileutils'
class Courseware::Printer

  def initialize(config, opts)
    @config  = config
    @course  = opts[:course]  or raise 'Course is a required option'
    @prefix  = opts[:prefix]  or raise 'Prefix is a required option'
    @version = opts[:version] or raise 'Version is a required option'

    raise unless can_print?

    @pdfopts = "--pdf-title '#{@course}' --pdf-author '#{@config[:pdf][:author]}' --pdf-subject '#{@config[:pdf][:subject]}'"
    @pdfopts << " --disallow-modify" if @config[:pdf][:protected]

    if @config[:pdf][:watermark]
      @password        = Courseware.question('Enter desired password:')
      @watermark_style = File.join(@config[:cachedir], 'templates', 'watermark.css')
      @watermark_pdf   = File.join(@config[:cachedir], 'templates', 'watermark.pdf')
    end

    FileUtils.mkdir(config[:output]) unless File.directory?(config[:output])

    if block_given?
      yield self
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
              "  * https://confluence.puppetlabs.com/display/EDU/Licenses"

        Courseware.dialog('Printing toolchain unavailable.', msg)
        return false
      end
    end

    return true
  end

  def generate_pdf(subject)
    # TODO screen printing
    # @pdfopts << " #{SCREENHACK}"
    # @suffix = "-screen"

    # Build the filename for the output PDF. This is ugly.
    output = File.join(@config[:output], "#{@prefix}-")
    output << 'w-' if @config[:pdf][:watermark]
    case subject
    when :print
      output << "#{@version}.pdf"
    when :exercises, :solutions
      output << "#{@version}-#{subject}.pdf"
      subject = "supplemental #{subject}"
    else
      raise "I don't know how to generate a PDF of #{subject}."
    end

    # clean out the static dir and build the source html
    FileUtils.rm_rf('static')
    system("showoff static #{subject}")
    if File.exists? 'cobrand.png'
      FileUtils.mkdir(File.join('static', 'image'))
      FileUtils.cp('cobrand.png', File.join('static', 'image', 'cobrand.png'))
    end
    FileUtils.mkdir(@config[:output]) unless File.directory?(@config[:output])

    case @config[:renderer]
    when :wkhtmltopdf
      command = ['wkhtmltopdf', '-s', 'Letter', '--print-media-type', '--quiet']
      command << ['--footer-left', "#{@course} #{@version}", '--footer-center', '[page]']
      command << ['--footer-right', "©#{Time.now.year} Puppet Labs", '--header-center', '[section]']
      command << ['--title', @course, File.join('static', 'index.html'), output]
      system(*command.flatten, STDERR=>'/dev/null') # TODO: figure out what's not loading
  #    raise 'Error generating PDF files' unless $?.success? # won't work until we figure out the ContentNotFoundError

      if `pdftk #{output} dump_data | grep NumberOfPages`.chomp == 'NumberOfPages: 1'
        puts "#{output} is empty; aborting and cleaning up."
        FileUtils.rm(output)
        return
      end

      scratchfile = File.join(@config[:output], 'scratch.pdf')
      command = ['pdftk', output, 'output', scratchfile]
      command << ['owner_pw', @config[:pdf][:password], 'allow', 'printing', 'CopyContents']
      command << ['background', @watermark_pdf] if @config[:pdf][:watermark]
      command << ['user_pw', @password] if @password
      system(*command.flatten)
      raise 'Error watermarking PDF files' unless $?.success?
      FileUtils.mv(scratchfile, output) if File.exists? scratchfile

    when :prince
      command = ['prince', File.join('static', 'index.html')]
      command << ['--pdf-title', @course, '--pdf-author', @config[:pdf][:author], '--pdf-subject', @config[:pdf][:subject], '--disallow-modify']
      command << ['--style', @watermark_style] if @config[:pdf][:watermark]
      command << ['--encrypt', '--user-password', @password] if @password
      command << ['--license-file', config[:pdf][:license]] if (@config[:pdf][:license] and File.exists? @leeconfig[:pdf][:license])
      command << ['-o', output]
      system(*command.flatten)
      raise 'Error generating PDF files' unless $?.success?
    end

    FileUtils.rm_rf('static')
  end

end
