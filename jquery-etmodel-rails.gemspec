# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name        = "jquery-etmodel-rails"
  s.version     = 0.1
  # s.platform    = Gem::Platform::RUBY
  s.authors     = ["Quintel Intelligence"]
  s.email       = ["info@quintel.com"]
  # s.homepage    = "http://rubygems.org/gems/jquery-rails"
  s.summary     = "jquery.etmodel.js as a rails plugin"
  s.description = "Easy way to integrate the jquery.etmodel.js plugin to a rails app."

  s.required_rubygems_version = ">= 1.3.6"

  s.files        = `git ls-files`.split("\n")
  s.executables  = `git ls-files -- bin/*`.split("\n").map { |f| File.basename(f) }
  # s.require_path = 'lib'
end