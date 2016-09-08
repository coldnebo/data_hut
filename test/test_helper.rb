unless ENV["TRAVIS"] == "1"
  require 'simplecov'
  SimpleCov.start

  require 'pry'
end


require 'minitest/autorun'
require 'mocha/setup'
require_relative 'filter_warnings'

require File.expand_path(File.join(*%w[.. lib data_hut]), File.dirname(__FILE__))
