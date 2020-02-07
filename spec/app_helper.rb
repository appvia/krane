require 'rubygems'
require 'bundler'
Bundler.setup(:default, :development)

require 'vendor'
require 'rspec'
require 'factory_bot'

dir = File.expand_path(File.join(File.dirname(__FILE__), '../lib/**.rb'))

Dir[dir].each {|f| require f}
