class Courseware
  require 'courseware/cache'
  require 'courseware/composer'
  require 'courseware/generator'
  require 'courseware/manager'
  require 'courseware/printer'
  require 'courseware/repository'
  require 'courseware/utils'

  def initialize(config, configfile)
    @config     = config
    @configfile = configfile
    @cache      = Courseware::Cache.new(config)
    @generator  = Courseware::Generator.new(config)

    if Courseware::Repository.repository?
      @repository = Courseware::Repository.new(config)
      @manager    = Courseware::Manager.new(config, @repository)
    else
      require 'courseware/dummy'
      @repository = Courseware::Dummy.new(config)
      @manager    = Courseware::Dummy.new(config)
      $logger.debug "Running outside a valid git repository."
    end
  end

  def options(opts)
    raise ArgumentError, "One or two arguments expected, not #{opts.inspect}" unless opts.size.between?(1,2)
    if opts.include? :section
      section = opts[:section]
      setting, value = opts.reject {|key, value| key == :section }.first
      @config[section][setting] = value
    else
      setting, value = opts.first
      @config[setting] = value
    end
  end

  def print(subject)
    $logger.debug "Printing #{subject}"

    #TODO: This should not be duplicated!
    opts = {
      :course  => @manager.coursename,
      :prefix  => @manager.prefix,
      :version => @repository.current(@manager.prefix),
    }
    Courseware::Printer.new(@config, opts) do |printer|
      subject.each do |item|
        case item
        when :handouts
          printer.handouts

        when :exercises
          printer.exercises

        when :solutions
          printer.solutions

        when :guide
          printer.guide

        else
          $logger.error "The #{item} document type does not exist."
        end
      end
    end
  end

  def wordcount(subject)
    @manager.wordcount(subject)
  end

  def generate(subject)
    $logger.debug "Generating #{subject}"
    if subject.first == :skeleton
      subject.shift
      subject.each do |course|
        @generator.skeleton course.to_s
      end
    else
      subject.each do |item|
        case item
        when :config
          @generator.saveconfig @configfile

        when :styles
          course = @manager.coursename
          prefix = @manager.prefix
          @generator.styles(course, @repository.current(prefix))

        when :links
          @generator.links

        when :metadata
          @generator.metadata

        when :rakefile
          @generator.rakefile

        when :shared
          @generator.shared

        else
          $logger.error "I don't know how to generate #{item}!"
        end
      end
    end

  end

  def validate(subject)
    $logger.debug "Validating #{subject}"
    subject.each do |item|
      case item
      when :obsolete
        @manager.obsolete

      when :missing
        @manager.missing

      when :lint
        @manager.lint

      else
        $logger.error "I don't know how to do that yet!"
      end
    end

    $logger.warn "Found #{@manager.errors} errors and #{@manager.warnings} warnings."
    exit @manager.errors + @manager.warnings
  end

  def release(subject)
    case subject

    when :major, :minor, :point
      $logger.debug "Creating a #{subject} release."
      @manager.release subject

    when :notes
      $logger.debug "Generating release notes."
      @manager.releasenotes

    else
      $logger.error "I don't know how to do that yet!"
    end
  end

  def compose(subject)
    Courseware::Composer.new(@config).build(subject)
  end

  def package(subject)
    Courseware::Composer.new(@config).package(subject)
  end

  def debug
    require 'pry'
    binding.pry
  end

end
