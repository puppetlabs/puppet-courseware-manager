require 'courseware/printer'
require 'courseware/repository'

class Courseware::Manager
  require 'courseware/manager/validators'

  attr_reader :coursename, :prefix, :warnings, :errors

  def initialize(config, repository=nil, generator=nil)
    @config     = config
    @repository = repository || Courseware::Repository.new(config)
    @generator  = generator  || Courseware::Generator.new(config)
    @warnings   = 0
    @errors     = 0

    if File.exists?(@config[:presfile])
      showoff     = JSON.parse(File.read(@config[:presfile]))
      @coursename = showoff['name']
      @prefix     = showoff['name'].gsub(' ', '_')
      @sections   = showoff['sections']
    end
  end

  def update_partner_pres
    return unless @config.include? :partner

    $logger.debug 'Creating partner presentation'
    partner = JSON.parse(File.read(@config[:presfile]))
    partner['issues'] = @config[:collector] if @config.include? :collector
    raise 'Partner patch failed!' unless File.write(@config[:partner], JSON.pretty_generate(partner))
  end

  def pointrelease
    raise 'This task must be run from within a course directory' unless @repository.courselevel?
    raise 'You should release from the master branch' unless @repository.on_branch? 'master'
    raise 'Your working directory has local modifications' unless @repository.clean?

    version = Courseware.increment(@repository.current(@coursename))
    Courseware.bailout?("Building a release for #{@coursename} version #{version}.")

    raise "Release notes not updated for #{version}" unless Courseware.grep(version, 'Release-Notes.md')

    Courseware.dialog('Last Repository Commit', @repository.last_commit)
    Courseware.bailout?('Abort now if the commit message displayed is not what you expected.')

    @generator.styles(@coursename, version)

    opts = {
      :course  => @coursename,
      :prefix  => @prefix,
      :version => version,
    }
    Courseware::Printer.new(@config, opts) do |printer|
      printer.print
    end

    system("open #{@config[:output]} >/dev/null 2>&1")
    Courseware.dialog('Point of No Return', 'Proceeding past this point will result in permanent repository changes.')
    Courseware.bailout?('Please inspect the generated PDF files and abort if corrections must be made.') do
      @repository.discard(@config[:stylesheet])
    end

    update_partner_pres
    @repository.commit(@config[:partner], @config[:stylesheet], "Updating for #{@coursename} release #{version}")
    @repository.tag("#{@prefix}-#{version}", "Releasing #{@coursename} version #{version}")
    puts "Release shipped. Please upload PDF files to printer and break out the bubbly."
  end

end
