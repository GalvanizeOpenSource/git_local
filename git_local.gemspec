# coding: utf-8

lib = File.expand_path("../lib", __FILE__)
$:.unshift(lib) unless $:.include?(lib)
require "git_local/version"

Gem::Specification.new do |spec|
  spec.name          = "git_local"
  spec.version       = GitLocal::VERSION
  spec.authors       = ["Galvanize Product"]
  spec.email         = ["dev@galvanize.com"]

  spec.summary       = "A lightweight git command line wrapper in Ruby"
  spec.homepage      = "https://github.com/GalvanizeOpenSource/git_local"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.12"
  spec.add_development_dependency "pry", "~> 0.10.4"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "rspec_junit_formatter"
  spec.add_development_dependency "rubocop"

  spec.required_ruby_version = "~> 2.0"
end
