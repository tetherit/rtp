# frozen_string_literal: true

require 'spec_helper'
require 'rtp'

describe Kernel do
  def self.requires
    Dir[File.dirname(__FILE__) + '/../lib/rtp/**/*.rb']
  end

  # Try to require each of the files in RTP
  requires.each do |r|
    it "should require #{r}" do
      # A require returns true if it was required, false if it had already been
      # required, and nil if it couldn't require.
      Kernel.require(r.to_s).should_not be_nil
    end
  end
end

describe RTP do
  it 'should have a VERSION constant' do
    RTP.const_defined?('VERSION').should be_truthy
  end
end
