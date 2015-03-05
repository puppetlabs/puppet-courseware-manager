require 'json'
require 'yaml'
require 'fileutils'
class Courseware::Generator

  def initialize(config)
    @config = config
  end

  def saveconfig(configfile)
    $logger.warn "Saving configuration"
    File.write(configfile, @config.to_yaml)
  end

  def skeleton(dest)
    source = File.join(@config[:cachedir], 'templates', 'skeleton')
    FileUtils.cp_r(source, dest)

    Dir.chdir(dest) do
      links
      styles(course, '0.0.1')
      metadata(dest)
    end
  end

  def styles(course, version)
    File.open(@config[:stylesheet], 'w') do |f|
      $logger.warn "Updating stylesheet for #{course} version #{version}."
      template = File.join(@config[:cachedir], 'templates', 'showoff.css.erb')
      f.write ERB.new(File.read(template, nil, '-')).result(binding)
    end
  end

  def links
    filename = File.join(@config[:cachedir], 'templates', 'links.json')
    JSON.parse(File.read(filename)).each do |file, target|
      $logger.warn "Linking #{file} -> #{target}"
      File.ln_sf(target, file)
    end
  end

  def metadata(dest)
    coursename  = Courseware.question('Choose a one-word codename for this course:', dest.capitalize)
    description = Courseware.question('Please type a short description of the course:')
    component   = Courseware.get_component

    filename = File.join(@config[:cachedir], 'templates', 'showoff.json')
    metadata = JSON.parse(File.read(filename))

    metadata['name']        = coursename
    metadata['description'] = description

    metadata['edit']   = "https://github.com/puppetlabs/#{config[:github][:repository]}/edit/qa/review/#{coursename}/#{dest}/"
    metadata['issues'] = "http://tickets.puppetlabs.com/secure/CreateIssueDetails!init.jspa?pid=10302&issuetype=1&components=#{component}&priority=6&summary="

    File.write('showoff.json', JSON.pretty_generate(metadata))
  end
end
