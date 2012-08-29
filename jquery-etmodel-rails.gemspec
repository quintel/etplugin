require File.expand_path('../lib/jquery-etmodel/rails/version', __FILE__)

Gem::Specification.new do |s|
  s.name        = "jquery-etmodel-rails"
  s.version     = JqueryEtmodel::Rails::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Quintel Intelligence"]
  s.email       = ["info@quintel.com"]
  # s.homepage    = "http://rubygems.org/gems/jquery-etmodel-rails"
  s.summary     = "jquery.etmodel.js as a rails plugin"
  s.description = "Easy way to integrate the jquery.etmodel.js plugin to a rails app."

  s.required_rubygems_version = ">= 1.3.6"
  # s.rubyforge_project         = "etmodel-rails"

  s.add_dependency "railties", ">= 3.1"
  s.add_development_dependency "rails", ">= 3.1"

  s.files        = `git ls-files`.split("\n")
  s.require_path = 'lib'
end
