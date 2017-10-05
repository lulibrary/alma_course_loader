# coding: utf-8

lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'alma_course_loader/version'

Gem::Specification.new do |spec|
  spec.name          = 'alma_course_loader'
  spec.version       = AlmaCourseLoader::VERSION
  spec.authors       = ['Lancaster University Library']
  spec.email         = ['library.dit@lancaster.ac.uk']

  spec.summary       = 'Support for creating Alma course loader files'
  spec.description   = 'This gem provides basic support for creating Alma ' \
                       'course loader files.'
  spec.homepage      = 'https://github.com/lulibrary/alma_course_loader'
  spec.license       = 'MIT'
  spec.files = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_dependency 'clamp'
  spec.add_dependency 'dotenv'

  spec.add_development_dependency 'bundler'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'minitest'
  spec.add_development_dependency 'minitest-reporters'
  spec.add_development_dependency 'rubocop'
end