require 'courseware/printer'
require 'courseware/repository'
require 'io/console'
require 'nokogiri'

class Courseware::Manager
  require 'courseware/manager/validators'

  attr_reader :coursename, :prefix, :warnings, :errors

  def initialize(config, repository=nil, generator=nil, printer=nil)
    @config     = config
    @repository = repository || Courseware::Repository.new(config)
    @generator  = generator  || Courseware::Generator.new(config)
    @warnings   = 0
    @errors     = 0

    return if @config[:presfile] == :none

    # if :presfile is an array, we're making a release, so look at the "main" presfile
    presfile    = @config[:presfile].is_a?(String) ? @config[:presfile] : 'showoff.json'
    showoff     = Courseware.parse_showoff(presfile)
    @coursename = showoff['name']
    @prefix     = showoff['name'].gsub(' ', '_')
    @password   = showoff['key']
  end

  def releasenotes
    courselevel!
    master!
    clean!

    @repository.update
    current = @repository.current(@coursename)
    version = Courseware.increment(current)
    tag     = "#{@coursename}-#{current}"

    notes = @repository.releasenotes(tag, version)

    # print to screen
    puts notes

    # and copy if on OS X
    begin
      IO.popen('pbcopy', 'w') { |f| f.puts notes }
      puts
      puts "{{ Copied to clipboard }}"
    rescue
    end
  end

  def release(type)
    courselevel!
    master!
    clean!

    @repository.update
    version = Courseware.increment(@repository.current(@coursename), type)
    Courseware.bailout?("Building a release for #{@coursename} version #{version}.")

    raise "Release notes not updated for #{version}" if Dir.glob('Release-Notes*').select { |path| Courseware.grep(version, path) }.empty?

    Courseware.dialog('Last Repository Commit', @repository.last_commit)
    Courseware.bailout?('Abort now if the commit message displayed is not what you expected.')
    build_pdfs(version)
    point_of_no_return
    Courseware.bailout?('Please inspect the generated PDF files and abort if corrections must be made.', true) do
      @repository.discard(@config[:stylesheet])
    end

    @repository.commit(@config[:stylesheet], "Updating for #{@coursename} release #{version}")
    @repository.tag("#{@prefix}-#{version}", "Releasing #{@coursename} version #{version}")

    # places the PDF files should be uploaded to
    @config[:release][:links].each do |link|
      system("open #{link}")
    end

    puts "Release shipped. Please upload PDF files to printer and break out the bubbly."
  end

  def wordcount(subject)
    $logger.debug "Counting words for #{subject}"
    opts = print_opts(@repository.current(prefix))
    puts "Words longer than a single character:"
    Courseware::Printer.new(@config, opts) do |printer|
      subject.each do |item|
        printer.generate_html(item)
        doc   = Nokogiri::HTML(File.read('static/index.html'))
        count = doc.css('body').text.split.select {|w| w.size > 1 }.count

        puts "  * #{item}: #{count}"

        FileUtils.rm_rf('static')
      end
    end
  end

private
  def toplevel!
    raise 'This task must be run from the repository root.' unless @repository.toplevel?
  end

  def courselevel!
    raise 'This task must be run from within a course directory' unless @repository.courselevel?
  end

  def master!
    raise 'You should release from the master branch' unless @repository.on_branch? 'master'
  end

  def clean!
    raise 'Your working directory has local modifications' unless @repository.clean?
  end

  def point_of_no_return
    Courseware.dialog('Point of No Return', 'Proceeding past this point will result in permanent repository changes.')
  end

  def build_pdfs(version)
    # This data structure dance is because the printer expects a configuration.
    # It could be rewritten at some point to accept an array of presfiles, but
    # this was more expedient and fewer moving parts.
    config   = @config.dup
    variants = Array(config[:presfile])

    @generator.styles(@coursename, version)
    # print each variant selected
    variants.each do |variant|
      config[:presfile] = variant
      Courseware::Printer.new(config, print_opts(version)) do |printer|
        printer.print
      end
    end

    system("open #{@config[:output]} >/dev/null 2>&1")
  end

  def print_opts(version)
    {
      :course  => @coursename,
      :prefix  => @prefix,
      :version => version,
    }
  end

end
