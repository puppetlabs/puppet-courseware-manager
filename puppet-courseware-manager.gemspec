$:.unshift File.expand_path("../lib", __FILE__)
require 'courseware/version'
require 'date'

Gem::Specification.new do |s|
  s.name              = "puppet-courseware-manager"
  s.version           = Courseware::VERSION
  s.licenses          = ['Apache-2.0']
  s.date              = Date.today.to_s
  s.summary           = "Manage the development lifecycle of Puppet courseware. Not for general consumption."
  s.homepage          = "http://github.com/puppetlabs/courseware-manager"
  s.email             = "education@puppetlabs.com"
  s.authors           = ["Ben Ford"]
  s.has_rdoc          = false
  s.require_path      = "lib"
  s.executables       = %w( courseware )
  s.files             = %w( CHANGELOG.txt README.txt LICENSE )
  s.files            += Dir.glob("lib/**/*")
  s.files            += Dir.glob("bin/**/*")
  s.files            += Dir.glob("doc/**/*")

  s.add_runtime_dependency  "mdl",       '~> 0.2'
  s.add_runtime_dependency  "showoff",   '~> 0.10'
  s.add_runtime_dependency  "word_wrap", '~> 1.0'

  s.description       = <<-desc
  Manage the development lifecycle of Puppet courseware. This tool is not
  required for presenting the material or for contributing minor updates.

  This tool is not intended for general usage. If you are not a Puppet instructor
  or an authorized training partner, this gem will have little interest for you.
  desc
end
