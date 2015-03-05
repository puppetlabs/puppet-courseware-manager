class Courseware::Manager

  attr_reader :coursename, :prefix

  def initialize(config)
    @config = config

    if File.exists?(@config[:presfile])
      showoff     = JSON.parse(File.read(@config[:presfile]))
      @coursename = showoff['name']
      @prefix     = showoff['name'].gsub(' ', '_')
    end

  end


end
