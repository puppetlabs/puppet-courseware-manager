class Courseware::Dummy
  attr_reader :coursename, :prefix

  def initialize(config, repository=nil, generator=nil, printer=nil)
    @config     = config

    showoff     = Courseware.parse_showoff(@config[:presfile])
    @coursename = showoff['name']
    @prefix     = showoff['name'].gsub(' ', '_')
    @sections   = showoff['sections']
    @password   = showoff['key']
    @current    = showoff['courseware_release']
  end

  def current(prefix)
    @current
  end

  def method_missing(meth, *args, &block)
    raise "Cannot call #{meth} without a working courseware repository"
  end
end
