class Courseware
  require 'courseware/cache'
  require 'courseware/generator'
  require 'courseware/repository'
  require 'courseware/utils'

  def initialize(config, configfile)
    @config     = config
    @configfile = configfile
    @cache      = Courseware::Cache.new(config)
    @repository = Courseware::Repository.new(config)
    @generator  = Courseware::Generator.new(config)
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
    subject.each do |item|
      case item
      when :config
        @generator.saveconfig @configfile

      when :styles
        @generator.styles

      when :links
        @generator.links

      when :skeleton
        @generator.skeleton

      end
    end

  end

  def validate(subject)
    $logger.debug "Validating #{subject}"

  end

  def release(subject)
    $logger.debug "Releasing #{subject}"

  end

  def review
    $logger.debug "Starting quarterly review."

  end

end
