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

  spec.add_dependency 'clamp', '~> 1.1'
  spec.add_dependency 'dotenv', '~> 2.2'

  spec.add_development_dependency 'bundler', '~> 1.14'
  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_development_dependency 'minitest', '~> 5.0'
  spec.add_development_dependency 'minitest-reporters', '~> 1.1'
  spec.add_development_dependency 'rubocop', '~> 0.49'
end