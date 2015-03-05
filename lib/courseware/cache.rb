require 'fileutils'
class Courseware::Cache

  def initialize(config)
    @config = config

    clone
    update
  end

  def clone
    templates = File.join(@config[:cachedir], 'templates')

    FileUtils.mkdir_p(@config[:cachedir]) unless File.exists? @config[:cachedir]
    system('git', 'clone', @config[:templates], templates) unless File.exists? templates
  end

  def update
    $logger.debug "Updating template cache..."
    git('templates', 'pull', '--quiet', 'origin', 'master')
  end

  def clear
    FileUtils.rm_rf @config[:cachedir]
  end

private
  def git(repo, *args)
    system('git', '--git-dir', File.join(@config[:cachedir], repo, '.git'), *args)
  end

end