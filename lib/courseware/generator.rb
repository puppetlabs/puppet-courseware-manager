require 'yaml'
class Courseware::Generator

  def initialize(config)
    @config = config
  end

  def saveconfig(configfile)
    $logger.warn "Saving configuration"
    File.write(configfile, @config.to_yaml)
  end
end
