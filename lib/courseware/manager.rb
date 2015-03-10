require 'courseware/printer'
require 'courseware/repository'
require 'io/console'

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
    build_pdfs(version)
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

    Courseware.release_notes_table(version)
    point_of_no_return
    Courseware.bailout?('Please abort if release notes or other updates are required.')

    @repository.tag(version, "Releasing quarterly release version #{version}")
    puts "Quarterly Release shipped. Please upload PDF files to printer and break out the bubbly."
  end

  def review
    courselevel?
    master?
    clean?

    version = Courseware.increment(@repository.current(nil), true)
    review  = "qa/review/#{@coursename}"
    release = "qa/#{version}/#{@coursename}"

    Courseware.bailout?("Reviewing #{@coursename} for a #{version} quarterly release.")
    raise "Reviewers for release #{version} should be listed in the Release Notes" unless Courseware.grep(version, 'Release-Notes.md')

    case
    when @repository.branch_exists?(release)
      raise "The release branch #{release} already exists!"
    when @repository.branch_exists?(review)
      Courseware.bailout?("Review branch #{review} already exists.")
      $logger.info "...updating review branch for #{@coursename}."
      @repository.checkout(review, true)
    else
      $logger.info "...creating review branch for #{@coursename}."
      @repository.create(review)
    end

    msg = 'Run through the entire course and make corrections as required. Remember that ' +
          'the bar for changes here is rather high. Only correct TINY typos and spelling ' +
          'and grammar mistakes or absolute blockers.'                                     +
          "\n\n"                                                                           +
          'Anything more should be filed as a ticket and resolved in a regular release '   +
          'cycle. The quarterly release should be polished, but should not have major '    +
          'changes. Please thoroughly review all corrections made.'                        +
          "\n\n"                                                                           +
          "Make corrections in the 'qa/review/#{@coursename}' branch by clicking the "     +
          "'Edit Slide' button in the Showoff toolbar."                                    +
          "\n\n"                                                                           +
          '#### Each time any reviewer makes a change, you should pull them down ####'     +
          "\n\n"                                                                           +
          " * Press [spacebar] to pull changes from GitHub as they're committed\n"         +
          " * Press [escape] to exit the review process when done.\n"
    Courseware.dialog("Starting Review Run for #{@coursename} #{version}", msg)

    puts "Starting the presentation in review mode. Switch to your browser now and load the presenter."
    showoff do
      system('open', 'http://localhost:9090/presenter')

      review_loop('Reviewing slides:') do
        @repository.pull(review)
        puts 'Please reload the slides.'
      end
    end

    build_pdfs(version)
    review_loop('Reviewing PDF files:') do
      @repository.pull(review)
      build_pdfs(version)
      puts 'Please reload the PDF files.'
    end

    point_of_no_return
    Courseware.bailout?("Merging reviewed release #{version}.") do
      @repository.discard(@config[:stylesheet])
      @repository.checkout('master')
    end

    update_partner_pres
    @repository.commit(@config[:partner], @config[:stylesheet], "Updating for #{@coursename} release #{version}")
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

  def build_pdfs(version)
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

  def review_loop(message)
    STDIN.raw do |io|
      STDIN.echo = false
      while true
        print "\r#{message}"

        input = STDIN.getc.chr
        printf("\r%s\r", ' ' * io.winsize[1])

        case input
        when ' ', "\r"
          STDIN.cooked do |io|
            yield if block_given?
          end
        when "\e"
          break
        end
      end
      STDIN.echo = true
    end
  end

  def showoff
    child = fork do
      $stdout.reopen File.new('/dev/null', 'w')
      $stderr.reopen File.new('/dev/null', 'w')
      exec('showoff', 'serve', '--review')
    end

    sleep 1
    yield if block_given?

     # Done with Showoff, we can terminate it now
    $logger.info "Terminating presentation"
    Process.kill('INT', child)
  end

end
