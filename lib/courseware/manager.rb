require 'courseware/printer'
require 'courseware/repository'

class Courseware::Manager
  require 'courseware/manager/validators'

  attr_reader :coursename, :prefix, :warnings, :errors

  def initialize(config, repository=nil, generator=nil, printer=nil)
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
    courselevel?
    master?
    clean?

    version = Courseware.increment(@repository.current(@coursename))
    Courseware.bailout?("Building a release for #{@coursename} version #{version}.")

    raise "Release notes not updated for #{version}" unless Courseware.grep(version, 'Release-Notes.md')

    Courseware.dialog('Last Repository Commit', @repository.last_commit)
    Courseware.bailout?('Abort now if the commit message displayed is not what you expected.')
    print(version)
    point_of_no_return
    Courseware.bailout?('Please inspect the generated PDF files and abort if corrections must be made.') do
      @repository.discard(@config[:stylesheet])
    end

    update_partner_pres
    @repository.commit(@config[:partner], @config[:stylesheet], "Updating for #{@coursename} release #{version}")
    @repository.tag("#{@prefix}-#{version}", "Releasing #{@coursename} version #{version}")
    puts "Release shipped. Please upload PDF files to printer and break out the bubbly."
  end

  def quarterlyrelease
    toplevel?
    master?
    clean?

    version = Courseware.increment(@repository.current(nil), true)
    Courseware.dialog("Creating Quarterly Release for #{version}", 'Please ensure that all courses in the repository have updated release notes and have been through the quarterly review process.')
    puts
    Courseware.release_notes_table(version)
    puts
    point_of_no_return
    Courseware.bailout?('Please abort if release notes or other updates are required.')

    @repository.tag(version, "Releasing quarterly release version #{version}")
    puts "Quarterly Release shipped. Please upload PDF files to printer and break out the bubbly."
  end

  def review
    courselevel?
    clean?

    version = Courseware.increment(@repository.current(nil), true)
    Courseware.bailout?("Reviewing #{@coursename} for a #{version} quarterly release.")
    raise "Reviewers for release #{version} should be listed in the Release Notes" unless Courseware.grep(version, 'Release-Notes.md')

    review = "qa/review/#{@coursename}"
    if @repository.branch_exists?(review)
      puts "...updating review branch for #{@coursename}."
      @repository.checkout(review, true)
    else
      master?
      puts "...creating review branch for #{@coursename}."
      @repository.create(review)
    end

    msg = 'Run through the entire course, both PDF files and the presentation. If any ' +
          'errors are discovered in either slides or PDF files then you should make '   +
          "updates to the 'qa/review/#{@coursename}' branch and run the review task "   +
          'again. Please make any repository updates using the GitHub editor by '       +
          'clicking the "Edit Slide" button in the Showoff toolbar.'
    Courseware.dialog('Starting Review Run', msg)

    child = fork do
      $stdout.reopen File.new('/dev/null', 'w')
      $stderr.reopen File.new('/dev/null', 'w')
      exec('showoff', 'serve', '--review')
    end

    puts "Starting the presentation in review mode. Switch to your browser now and load the presenter."
    sleep 1
    system('open', 'http://localhost:9090/presenter')
    sleep 10
    Courseware.bailout?("If changes were made, abort and run this task again. Otherwise continue to inspect PDF files.")

    # Done with Showoff, we can terminate it now
    $logger.info "Terminating presentation"
    Process.kill('INT', child)

    print(version)

    msg = 'If no corrections were made, then you may continue and merge any updates.' +
          'If errors were corrected in either slides or PDF files then you should '   +
          "abort now and run the quarterly_review task again and verify them.\n\n"    +
          'Proceeding past this point will result in permanent repository changes!'

    Courseware.dialog('Concluding Review Run', msg)
    Courseware.bailout?("Merging reviewed release #{version}.")

    update_partner_pres
    @repository.commit(@config[:partner], @config[:stylesheet], "Updating for #{@coursename} release #{version}")

    release = "qa/#{version}/#{@coursename}"
    @repository.create(release)
    @repository.merge(release)
    @repository.delete(review)
  end

private
  def toplevel?
    raise 'This task must be run from the repository root.' unless @repository.toplevel?
  end

  def courselevel?
    raise 'This task must be run from within a course directory' unless @repository.courselevel?
  end

  def master?
    raise 'You should release from the master branch' unless @repository.on_branch? 'master'
  end

  def clean?
    raise 'Your working directory has local modifications' unless @repository.clean?
  end

  def point_of_no_return
    Courseware.dialog('Point of No Return', 'Proceeding past this point will result in permanent repository changes.')
  end

  def print(version)
    opts = {
      :course  => @coursename,
      :prefix  => @prefix,
      :version => version,
    }

    @generator.styles(@coursename, version)
    Courseware::Printer.new(@config, opts) do |printer|
      printer.print
    end
    system("open #{@config[:output]} >/dev/null 2>&1")
  end
end
