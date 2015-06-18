require 'erb'
require 'json'
require 'yaml'
require 'fileutils'
class Courseware::Generator

  def initialize(config)
    @config = config
  end

  def saveconfig(configfile)
    $logger.info "Saving configuration to #{configfile}"
    File.write(configfile, @config.to_yaml)
  end

  def skeleton(dest)
    source = File.join(@config[:cachedir], 'templates', 'skeleton')
    FileUtils.cp_r(source, dest)

    Dir.chdir(dest) do
      course = metadata()
      styles(course, '0.0.1')

      default = Courseware::Repository.repository? ? 'P' : 'S'
      case Courseware.question('Should this be a (S)tandalone course or share assets with a (P)arent repository?', default)
      when 's','S'
        shared
        $logger.warn "Don't forget to create the GitHub repository for your new course following the EDU standard."
      else
        links
        $logger.warn "Don't forget to add, commit, & push this new course directory to the repository."
      end
    end
  end

  def shared
    source = File.join(@config[:cachedir], 'templates', 'shared')
    FileUtils.cp_r(source, '.')
  end

  def rakefile
    raise 'Update the toplevel Rakefile instead.' if File.symlink? 'Rakefile'
    source = File.join(@config[:cachedir], 'templates', 'Rakefile')
    FileUtils.cp(source, 'Rakefile')
  end

  def styles(course=nil, version=nil)
    File.open(@config[:stylesheet], 'w') do |f|
      $logger.info "Updating stylesheet for #{course} version #{version}."
      template = File.join(@config[:cachedir], 'templates', 'showoff.css.erb')
      f.write ERB.new(File.read(template), nil, '-').result(binding)
    end
  end

  def links
    filename = File.join(@config[:cachedir], 'templates', 'links.json')
    JSON.parse(File.read(filename)).each do |file, target|
      $logger.info "Linking #{file} -> #{target}"
      FileUtils.rm_rf(file) if File.exists?(file)
      FileUtils.ln_sf(target, file)
    end
  end

  def metadata
    location = File.basename Dir.pwd
    if File.exists?(@config[:presfile])
      metadata    = JSON.parse(File.read(@config[:presfile]))
      coursename  = metadata['name']
      description = metadata['description']
      component   = metadata['issues'].match(/components=(\d*)/)[1]
    else
      template    = File.join(@config[:cachedir], 'templates', 'showoff.json')
      metadata    = JSON.parse(File.read(template))
      coursename  = location.capitalize
      description = nil
      component   = nil
    end
    coursename  = Courseware.question('Choose a short name for this course:', coursename)
    description = Courseware.question('Please enter a description of the course:', description)
    component   = Courseware.get_component(component)

    metadata['name']        = coursename
    metadata['description'] = description
    metadata['edit']        = "https://github.com/puppetlabs/#{@config[:github][:repository]}/edit/qa/review/#{coursename}/#{location}/"
    metadata['issues']      = "http://tickets.puppetlabs.com/secure/CreateIssueDetails!init.jspa?pid=10302&issuetype=1&components=#{component}&priority=6&summary="

    $logger.info "Updating presentation file #{@config[:presfile]}"
    File.write(@config[:presfile], JSON.pretty_generate(metadata))
    coursename
  end
end
