# frozen_string_literal: true

require 'simplecov'

SimpleCov.start do
  add_group 'Lib', 'lib' do |src_file|
    src_file.filename !~ /spec/
  end

  add_group 'Specs', 'spec'
end

$LOAD_PATH.unshift("#{File.dirname(__FILE__)}/../lib")
