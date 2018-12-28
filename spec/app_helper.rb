require 'rubygems'
require 'bundler'
Bundler.require(:default)

require 'commander'
require 'colorize'
require 'redisgraph'

require 'active_support/core_ext/object/blank'
require 'active_support/core_ext/string'

dir = File.expand_path(File.join(File.dirname(__FILE__), '../lib/**.rb'))

Dir[dir].each {|f| require f}
