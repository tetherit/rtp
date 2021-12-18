# frozen_string_literal: true

$LOAD_PATH.push File.expand_path('lib', __dir__)
require 'rtp/version'

Gem::Specification.new do |s|
  s.metadata['rubygems_mfa_required'] = 'true'
  s.name = 'rtp'
  s.version = RTP::VERSION
  s.authors = ['Steve Loveless', 'Sujin Philip', 'Roman Gaufman']
  s.homepage = 'http://github.com/turboladen/rtp'
  s.email = 'steve.loveless@gmail.com'
  s.description = 'This is a pure Ruby implementation of RTP, initially geared \
   towards use with RTSP (but not limited to).'
  s.summary = 'Pure Ruby implementation of RTP'

  s.required_rubygems_version = '>=1.8.0'
  s.required_ruby_version = '>= 3.0.2'
  s.files = Dir.glob('{lib,spec,tasks}/**/*') + Dir.glob('*.rdoc') +
            %w[.gemtest Gemfile rtp.gemspec Rakefile]
  s.test_files = Dir.glob('spec/**/*')
  s.require_paths = 'lib'

  s.add_dependency 'bindata', '>= 2.4.10'
  s.add_dependency 'semantic_logger'

  s.add_development_dependency 'bundler'
  s.add_development_dependency 'rake'
  s.add_development_dependency 'rspec', '>= 3.10'
  s.add_development_dependency 'simplecov'
  s.add_development_dependency 'tailor', '>= 1.1.2'
  s.add_development_dependency 'yard', '>= 0.7.2'
end
