$:.unshift File.expand_path("../lib", __FILE__)
require 'courseware/version'
require 'date'

Gem::Specification.new do |s|
  s.name              = "courseware"
  s.version           = Courseware::VERSION
  s.licenses          = ['Apache-2.0']
  s.date              = Date.today.to_s
  s.summary           = "Manage the development lifecycle of Puppet Labs courseware."
  s.homepage          = "http://github.com/puppetlabs/courseware-manager"
  s.email             = "education@puppetlabs.com"
  s.authors           = ["Ben Ford"]
  s.has_rdoc          = false
  s.require_path      = "lib"
  s.executables       = %w( courseware )
  s.files             = %w( README.txt LICENSE )
  s.files            += Dir.glob("lib/**/*")
  s.files            += Dir.glob("bin/**/*")
  s.files            += Dir.glob("doc/**/*")

  s.add_runtime_dependency  "mdl",       '~> 0.2'
  s.add_runtime_dependency  "showoff",   '~> 0.10'
  s.add_runtime_dependency  "word_wrap", '~> 1.0'

  s.description       = <<-desc
  Manage the development lifecycle of Puppet Labs courseware. This tool is not
  required for presenting the material or for contributing minor updates.
  desc
end
