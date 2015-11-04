# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'terrachef/version'

Gem::Specification.new do |s|
  s.name          = project
  s.version       = Terrachef::VERSION
  s.authors       = ["Chris Doherty"]
  s.email         = ["chris@randomcamel.net"]

  s.summary       = "Use Chef DSL to write Terraform configurations."
  s.description   = s.summary
  s.homepage      = "https://github.com/randomcamel/terrachef"
  s.license       = "Apache 2.0"

  s.add_dependency "chef", "~> 12.5"
  s.add_dependency "cheffish"
  s.add_dependency "chefs"

  s.add_development_dependency "bundler", "~> 1.10"
  s.add_development_dependency "rake", "~> 10.0"
  s.add_development_dependency 'rspec'
  s.add_development_dependency 'cheffish'
  # s.add_development_dependency 'stove'
  s.add_development_dependency 'chef'
  s.add_development_dependency "pry-byebug"
  s.add_development_dependency "pry-stack_explorer"

  s.bindir       = 'bin'
  s.executables  = []
  s.require_path = 'files/lib'
  s.files = %w(LICENSE README.md CHANGELOG.md Gemfile Rakefile) + Dir.glob('{files/lib,spec}/**/*', File::FNM_DOTMATCH).reject {|f| File.directory?(f)}
end
