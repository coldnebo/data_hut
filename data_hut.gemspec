# -*- encoding: utf-8 -*-
require File.expand_path('../lib/data_hut/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Larry Kyrala"]
  gem.email         = ["larry.kyrala@gmail.com"]
  gem.description   = %q{A small, portable data warehouse for Ruby for analytics on anything!}
  gem.summary       = %q{Like a data warehouse, but smaller.}
  gem.homepage      = ""

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = "data_hut"
  gem.require_paths = ["lib"]
  gem.version       = DataHut::VERSION

  gem.add_dependency 'sequel'
  gem.add_dependency 'sqlite3'

  gem.add_development_dependency 'mocha'
  gem.add_development_dependency 'pry'
end
