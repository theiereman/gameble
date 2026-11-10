require "test_helper"
require_relative "../../support/holdings"
require_relative "../../support/market"

class Game::ArchiveStocksJobTest < ActiveSupport::TestCase
  include Holdings
  include MarketSettings

  test "performing the job sums the deposits into the stocks" do
    player = accounts_players(:player)
    card_season = catalog_card_seasons(:common_card_one)
    settings = open_market!
    hold(player, card_season.id, 2)
    Game::Market::EntrustCards.new.call(player:, lines: { card_season.id => 2 }, settings_token: settings.token).value!

    Game::ArchiveStocksJob.perform_now

    assert_equal({ card_season.id => 2 }, Game::Market::ArchiveStock.pluck(:card_season_id, :quantity).to_h)
  end

  test "the job queues on default" do
    assert_equal "default", Game::ArchiveStocksJob.new.queue_name
  end
end
