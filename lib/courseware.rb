class Courseware
  require 'courseware/cache'
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
      @repository = @manager = Courseware::Dummy.new
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

        else
          $logger.error "The #{item} document type does not exist."
        end
      end
    end
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
    $logger.debug "Releasing #{subject}"
    case subject
    when :point
      @manager.pointrelease

    when :quarterly
      @manager.quarterlyrelease

    else
      $logger.error "I don't know how to do that yet!"
    end
  end

  def review
    $logger.info "Starting quarterly review."
    @manager.review
  end

  def debug
    require 'pry'
    binding.pry
  end

end
