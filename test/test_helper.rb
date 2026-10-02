ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

# Build the Vite assets once, here, before the parallel workers fork. With
# autoBuild, workers that each find the build stale rebuild it at the same
# time, and one empties the output while another reads the manifest.
abort "Vite build failed: see log/test.log" unless ViteRuby.commands.build

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end
