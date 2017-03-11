require 'fileutils'
require 'rubygems'
class Courseware::Repository

  def initialize(config)
    @config = config
    return if @config[:nocache]

    raise 'This is not a courseware repository' unless Courseware::Repository.repository?
    configure_courseware
  end

  def tag(tag, message=nil)
    if tag
      system("git tag -a #{tag} -m '#{message}'")
    else
      system("git tag #{tag}")
    end

    system("git push upstream master")
    system("git push upstream #{tag}")
    system("git push courseware master")
    system("git push courseware #{tag}")
  end

  def update
    system('git fetch upstream')
    system('git fetch upstream --tags')
  end

  def create(branch)
    system("git checkout -b #{branch}")
    system("git push upstream #{branch}")
  end

  def checkout(branch, pull=false)
    system("git checkout #{branch}")
    pull(branch) if pull
  end

  def pull(branch)
    system('git', 'pull', 'upstream', branch)
  end

  def merge(branch)
    system('git checkout master')
    system("git merge #{branch}")
    system('git push upstream master')
  end

  def delete(branch)
    system("git branch -d #{branch}")
    system("git push upstream --delete #{branch}")
  end

  def commit(*args)
    message = args.pop
    args.each do |file|
      system('git', 'add', file)
    end
    system('git', 'commit', '-m', message)
  end

  def discard(*args)
    args.each do |file|
      $logger.warn "Discarding changes to #{file}"
      system('git', 'checkout', '--', file)
    end
  end

  def last_commit
    `git show --name-status --no-color`.chomp.gsub("\t", '    ')
  end

  def on_branch?(branch='master')
    `git symbolic-ref -q --short HEAD`.chomp == branch
  end

  def clean?
    system('git diff-index --quiet HEAD')
  end

  # clean working tree and no untracked files
  def pristine?
    clean? and `git ls-files --other --directory --exclude-standard`.empty?
  end

  def branch_exists?(branch)
    `git branch --list '#{branch}'` != ''
  end

  def toplevel?
    Dir.pwd == `git rev-parse --show-toplevel`.chomp
  end

  def courselevel?
    File.expand_path("#{Dir.pwd}/..") == `git rev-parse --show-toplevel`.chomp
  end

  def outstanding_commits(prefix, verbose=false)
    last = current(prefix)
    commits = `git log --no-merges --oneline #{prefix}-#{last}..HEAD -- .`.each_line.map {|line| line.chomp }

    verbose ? commits : commits.count
  end

  def releasenotes(last, version)
    str = "### #{version}\n"
    str << "{{{Please summarize the release here}}}\n"
    str << "\n"
    str << `git log --no-merges --pretty="format:* (%h) %s [%aN]" #{last}..HEAD -- .`
    str
  end

  # This gets a list of all tags matching a prefix.
  def tags(prefix, count=1)
    prefix ||= 'v' # even if we pass in nil, we want to default to this
    tags = `git tag -l '#{prefix}*'`.split("\n").sort_by { |tag| version(tag) }.last(count)
    tags.empty? ? ['v0.0.0'] : tags
  end

  def current(prefix)
    tags(prefix).first.gsub(/^#{prefix}-/, '')
  end

private

  def configure_courseware
    courseware = "#{@config[:github][:public]}/#{@config[:github][:repository]}"
    upstream   = "#{@config[:github][:development]}/#{@config[:github][:repository]}"

    # Check the origin to see which scheme we should use
    origin = `git config --get remote.origin.url`.chomp
    if origin =~ /^(git@|https:\/\/)github.com[:\/].*\/#{@config[:github][:repository]}(?:-.*)?(?:.git)?$/
      case $1
      when 'git@'
        ensure_remote('courseware', "git@github.com:#{courseware}.git")
        ensure_remote('upstream',   "git@github.com:#{upstream}.git")
      when 'https://'
        ensure_remote('courseware', "https://github.com/#{courseware}.git")
        ensure_remote('upstream',   "https://github.com/#{upstream}.git")
      end
    elsif origin.empty?
      $logger.warn 'Your origin remote is not set properly.'
      $logger.warn 'Generating PDF files and other local operations will work properly, but many repository actions will fail.'
    else
      raise "Your origin (#{origin}) does not appear to be configured correctly."
    end
  end

  def ensure_remote(remote, url)
    # If we *have* the remote, but it's not correct, then  let's repair it.
    if `git config --get remote.#{remote}.url`.chomp != url and $?.success?
      if Courseware.confirm("Your '#{remote}' remote should be #{url}. May I correct this?")
        raise "Error correcting remote." unless system("git remote remove #{remote}")
      else
        raise "Please configure your '#{remote}' remote before proceeding."
      end
    end

    # add the remote, either for the first time or because we removed it
    unless system("git config --get remote.#{remote}.url > /dev/null")
      # Add the remote if it doesn't already exist
      unless system("git remote add #{remote} #{url}")
        raise "Could not add the '#{remote}' remote."
      end
    end

    # for pedantry, validate the refspec too
    unless `git config --get remote.#{remote}.fetch`.chomp == "+refs/heads/*:refs/remotes/#{remote}/*"
      if Courseware.confirm("Your '#{remote}' remote has an invalid refspec. May I correct this?")
        unless system("git config remote.#{remote}.fetch '+refs/heads/*:refs/remotes/#{remote}/*'")
          raise "Could not repair the '#{remote}' refspec."
        end
      else
        raise "Please configure your '#{remote}' remote before proceeding."
      end

    end
  end

  # Gem::Version is used simply for semantic version comparisons.
  def version(tag)
    Gem::Version.new(tag.gsub(/^.*-?v/, '')) rescue Gem::Version.new(0)
  end

  def self.repository?
    system('git status >/dev/null 2>&1')
  end
end
