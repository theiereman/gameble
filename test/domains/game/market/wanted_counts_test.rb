require "test_helper"

class Game::Market::WantedCountsTest < ActiveSupport::TestCase
  setup do
    @viewer = accounts_players(:player)
    @other = accounts_players(:moderator)
    @card = catalog_cards(:common_card)
  end

  def want(player, reason, rarities = nil) = Game::Market::Wanted.insert_all([ { player_id: player.id, card_id: @card.id, reason:, rarities: } ])

  test "a goal counts at every rarity, an order at those it reaches, a player wanting by both once" do
    want(@other, "goal")
    want(@other, "order", [ 1, 2 ])
    want(accounts_players(:administrator), "order", [ 1, 2 ])

    counts = Game::Market::WantedCounts.call([ @card.id ], except: @viewer.id)

    assert_equal [ 2, 2, 1, 1, 1 ], Catalog::Rarity::TIERS.values.map { counts[[ @card.id, it.to_s ]] }
  end

  test "the viewer and a banned player are never counted, and a game nobody wants counts zero" do
    want(@viewer, "goal")
    want(accounts_players(:banned), "goal")

    counts = Game::Market::WantedCounts.call([ @card.id, catalog_cards(:rare_card).id ], except: @viewer.id)

    assert_equal 0, counts[[ @card.id, "common" ]]
    assert_equal 0, counts[[ catalog_cards(:rare_card).id, "rare" ]]
  end

  test "no card asks no query" do
    assert_equal({}, Game::Market::WantedCounts.call([], except: @viewer.id))
  end
end
