require 'fileutils'
class Courseware::Printer

  def initialize(config, opts)
    raise 'Printing toolchain not functional' unless system 'prince --version >/dev/null 2>&1'
    @config  = config
    @course  = opts[:course]  or raise 'Course must be set'
    @prefix  = opts[:prefix]  or raise 'Prefix must be set'
    @version = opts[:version] or raise 'Version must be set'

    @pdfopts = "--pdf-title '#{@course}' --pdf-author '#{@config[:pdf][:author]}' --pdf-subject '#{@config[:pdf][:subject]}'"
    @pdfopts << " --disallow-modify" if @config[:pdf][:protected]

    if @config[:pdf][:watermark]
      if password = Courseware.question('Enter desired password:')
        encrypt = " --encrypt --user-password '#{password}'"
      else
        encrypt = ''
      end

      style = templates = File.join(@config[:cachedir], 'templates', 'watermark.css')
      @pdfopts << " --style=#{style} #{encrypt}"

      @suffix = '-w'
    end

    FileUtils.mkdir(config[:output]) unless File.directory?(config[:output])
    clear
  end

  def checkparams
    raise 'Course must be set' unless @course
    raise 'Prefix must be set' unless @prefix
    raise 'Version must be set' unless @version
  end

  def filename(supplement=nil)
    if supplement
      File.join(@config[:output], "#{@prefix}#{@suffix}-#{@version}-#{supplement}.pdf")
    else
      File.join(@config[:output], "#{@prefix}#{@suffix}-#{@version}.pdf")
    end
  end

  def handouts
    checkparams
    puts "Generating handouts pdf for #{@course} #{@version}..."

    system('showoff static print')
    system("prince static/index.html #{@pdfopts} -o #{filename}")
  end

  def exercises
    checkparams
    puts "Generating exercise guide pdf for #{@course} #{@version}..."

    system('showoff static supplemental exercises')
    system("prince static/index.html #{@pdfopts} -o #{filename('exercises')}")
  end

  def solutions
    checkparams
    puts "Generating solutions guide pdf for #{@course} #{@version}..."

    system('showoff static supplemental solutions')
    system("prince static/index.html #{@pdfopts} -o #{filename('solutions')}")
  end

  def clear
    FileUtils.rm_rf('static')
  end
end
