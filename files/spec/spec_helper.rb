require 'terrachef'

require 'cheffish/rspec/chef_run_support'

require 'pp'

RSpec.configure do |config|
  config.filter_run focus: true
  config.run_all_when_everything_filtered = true

  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end
end

Chef::Log.init("/tmp/rspec-chef.log")
Chef::Log.level = :debug