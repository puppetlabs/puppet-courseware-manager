class Courseware
  require 'courseware/cache'
  require 'courseware/generator'
  require 'courseware/manager'
  require 'courseware/repository'
  require 'courseware/utils'

  def initialize(config, configfile)
    @config     = config
    @configfile = configfile
    @cache      = Courseware::Cache.new(config)
    @repository = Courseware::Repository.new(config)
    @generator  = Courseware::Generator.new(config)
    @manager    = Courseware::Manager.new(config, @repository)
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
    $logger.error "I don't know how to do that yet!"
  end

  def review
    $logger.debug "Starting quarterly review."
    $logger.error "I don't know how to do that yet!"
  end

end
