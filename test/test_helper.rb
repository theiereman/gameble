ENV["RAILS_ENV"] ||= "test"
# Time.now + n.days advances the wall clock in the system zone, so a daylight
# saving change within a test's window would shift it by an hour off CI's UTC.
ENV["TZ"] = "UTC"
require_relative "../config/environment"
require "rails/test_help"

# Build the Vite assets once, here, before the parallel workers fork. With
# autoBuild, workers that each find the build stale rebuild it at the same
# time, and one empties the output while another reads the manifest.
abort "Vite build failed: see log/test.log" unless ViteRuby.commands.build

# No test reaches Steam: outside production the Web API key is read from
# config/steam_api.key, which may hold the author's real key. The client
# answers from an empty set of Faraday test stubs unless a test stubs it
# (SteamApiStubs, which restores this on unstub); an unstubbed call raises.
# Set here, before the parallel workers fork.
Steam::WebApi.adapter = [ :test, Faraday::Adapter::Test::Stubs.new ]
# Nor does a card's art fetch (ShareImageArt stubs it).
CardShareImage::Art.adapter = [ :test, Faraday::Adapter::Test::Stubs.new ]

require_relative "support/rated_cards"

module ActiveSupport
  class TestCase
    include RatedCards

    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # The draw pool is held per process and outlives the transaction each test rolls back.
    setup { Game::DrawPool.reset! }

    # Add more helper methods to be used by all tests here...
  end
end
