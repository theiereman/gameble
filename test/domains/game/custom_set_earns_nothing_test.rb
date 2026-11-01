require "test_helper"
require_relative "../../support/game_packs"
require_relative "../../support/custom_sets"
require_relative "../../support/holdings"

# A custom set has no tiers and earns nothing: the opening that completes it
# writes and announces what the same opening writes for a player without it.
class Game::CustomSetEarnsNothingTest < ActiveSupport::TestCase
  include GamePacks
  include CustomSets
  include Holdings

  def rewards(player)
    [ Game::SetTier, Game::FeedEntry, Game::CardBackUnlock, Game::AchievementUnlock ].to_h { [ it.name, it.where(player_id: player.id).count ] }
      .merge("allocation" => Game::PlayerState.where(player_id: player.id).pick(:allocation_received_season, :allocation_seen_season))
  end

  # The opening's event types.
  def open_portals(player)
    hold(player, catalog_card_seasons(:common_card_one).id)
    hold(player, catalog_card_seasons(:legendary_card_one).id)
    create_pack(player, cards: Array.new(Game::Pack::SIZE, catalog_card_seasons(:portal_one).id))
    before = game_events(player).size
    Game::OpenPack.new.call(player:).value!
    game_events(player).drop(before).map(&:event_type)
  end

  test "an opening that completes a custom set that is no goal records and announces nothing for it" do
    player = accounts_players(:player)
    without = accounts_players(:moderator)
    custom_set = create_custom_set(player, card_ids: fixture_card_ids.values_at(0, 3, 4))

    announced = open_portals(player)

    assert_equal open_portals(without), announced
    assert Game::CustomSetStandings.call(player, tokens: [ custom_set.token ]).sole.complete?
    assert_equal rewards(without), rewards(player)
  end
end
