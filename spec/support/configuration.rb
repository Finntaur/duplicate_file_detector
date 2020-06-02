require 'rspec'
require 'factory_bot'

require File.join(__dir__, 'factory_bot')

Dir[File.join(__dir__, '..', '..', 'lib', 'dfd', '**', '*.rb')].each { |src| require src }

$STDOUT = nil
