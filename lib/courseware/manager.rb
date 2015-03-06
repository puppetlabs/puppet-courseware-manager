class Courseware::Manager
  require 'courseware/manager/validators'

  attr_reader :coursename, :prefix, :warnings, :errors

  def initialize(config, repository=nil)
    @config     = config
    @repository = repository
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


end
