$:.unshift File.expand_path("../../lib", __FILE__)
require "git_local"
require "pry"

RSpec.configure do |config|
  config.include GitLocal::TestHelpers
end
