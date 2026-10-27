require "test_helper"
require_relative "../../support/game_packs"

class Game::ProfileActivityTest < ActiveSupport::TestCase
  include GamePacks

  setup do
    @player = accounts_players(:player)
    @other = accounts_players(:moderator)
  end

  def trade(status, proposer: @player, recipient: @other)
    low, high = [ proposer.id, recipient.id ].minmax
    Game::Trade.create!(low_player_id: low, high_player_id: high, proposer_id: proposer.id, recipient_id: recipient.id, status:,
      proposed_at: 1.day.ago, expires_at: 6.days.from_now)
  end

  def discover(card_name, player: @player)
    Game::FirstDiscovery.find_by!(card_season_id: catalog_card_seasons(card_name).id).update!(player_id: player.id)
  end

  test "the capsules opened, the cards first discovered and the trades concluded, either side, in one query" do
    2.times { create_pack(@player, opened_at: 1.hour.ago) }
    create_pack(@player)
    create_pack(@other, opened_at: 1.hour.ago)
    discover(:common_card_one)
    discover(:rare_card_one)
    discover(:legendary_card_one, player: @other)
    trade("accepted")
    trade("accepted", proposer: @other, recipient: @player)
    trade("declined")

    activity = nil
    assert_queries_count(1) { activity = Game::ProfileActivity.call(@player) }

    assert_equal Game::ProfileActivity::Activity.new(packs_opened: 2, first_discoveries: 2, trades_concluded: 2), activity
  end

  test "zeros for a player with no history, and for nil without a query" do
    assert_equal Game::ProfileActivity::NONE, Game::ProfileActivity.call(@player)
    assert_queries_count(0) { assert_equal Game::ProfileActivity::NONE, Game::ProfileActivity.call(nil) }
  end
end
