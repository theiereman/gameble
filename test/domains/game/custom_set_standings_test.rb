require "test_helper"
require_relative "../../support/holdings"
require_relative "../../support/custom_sets"

# A player's own sets as their album and list read them: oldest first, each
# with its games in the order picked and the games held in any edition.
class Game::CustomSetStandingsTest < ActiveSupport::TestCase
  include Holdings
  include CustomSets

  setup do
    @player = accounts_players(:player)
  end

  def earlier_edition(card)
    season = Catalog::Season.create!(status: :published, number: Catalog::Season.next_number, published_at: Time.current)
    Catalog::CardSeason.insert_all!([ { card_id: card.id, season_id: season.id, prestige_score: 0.5, rating: 80.0, rarity: "rare", number: 1 } ],
      returning: :id).rows.flatten.sole
  end

  test "each set, oldest first, with its games in their order, the games held in any edition, its count and no tiers, in three queries" do
    ids = fixture_card_ids
    first = create_custom_set(@player, name: "Mes favoris", card_ids: ids.values_at(3, 0, 1))
    second = create_custom_set(@player, name: "Tous", card_ids: ids)
    create_custom_set(accounts_players(:moderator), card_ids: ids)
    hold(@player, earlier_edition(catalog_cards(:portal)))
    hold(@player, catalog_card_seasons(:rare_card_one).id)
    hold(@player, catalog_card_seasons(:common_card_one).id, 0)

    standings = assert_queries_count(3) { Game::CustomSetStandings.call(@player) }

    assert_equal [ first.token, second.token ], standings.map(&:token)
    mine = standings.first
    assert_equal [ "Mes favoris", "custom", ids.values_at(3, 0, 1), [ ids[3] ] ], [ mine.name, mine.kind, mine.card_ids, mine.held_card_ids ]
    assert_equal [ 1, 3, false, true ], [ mine.held, mine.total, mine.complete?, mine.custom? ]
    assert_equal [ ids[2], ids[3] ], standings.last.held_card_ids
    standing = mine.to_set_standing
    assert_equal [ nil, 1, 3, {} ], [ standing.set_id, standing.held, standing.total, standing.tiers ]
    assert_nil standing.reached_tier
  end

  test "the sets asked by token only; a set held whole is complete" do
    ids = fixture_card_ids.first(3)
    create_custom_set(@player, name: "Autre", card_ids: ids)
    asked = create_custom_set(@player, card_ids: ids)
    %i[common_card_one uncommon_card_one rare_card_one].each { hold(@player, catalog_card_seasons(it).id) }

    standings = Game::CustomSetStandings.call(@player, tokens: [ asked.token ])

    assert_equal [ asked.token ], standings.map(&:token)
    assert standings.sole.complete?
  end

  test "no player, no set or no token asked: nothing, without a query" do
    assert_queries_count(0) do
      assert_equal [], Game::CustomSetStandings.call(nil)
      assert_equal [], Game::CustomSetStandings.call(@player, tokens: [])
    end
    assert_equal [], Game::CustomSetStandings.call(@player)
  end
end
