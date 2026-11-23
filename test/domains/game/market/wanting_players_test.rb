require "test_helper"

class Game::Market::WantingPlayersTest < ActiveSupport::TestCase
  setup do
    @player = accounts_players(:player)
    @other = accounts_players(:moderator)
    @common = catalog_card_seasons(:common_card_one)
  end

  def want(player, reason, rarities = nil)
    Game::Market::Wanted.insert_all([ { player_id: player.id, card_id: @common.card_id, reason:, rarities: } ])
  end

  def rare_edition
    season = Catalog::Season.create!(status: :draft, number: Catalog::Season.next_number)
    Catalog::CardSeason.create!(card_id: @common.card_id, season_id: season.id, prestige_score: 0.5, rating: 80.0, rarity: "rare", number: 1)
  end

  test "an order counts at the rarities it reaches, a goal at every rarity" do
    want(@player, "order", [ 1 ])
    want(@other, "goal")

    assert_equal [ @player.id, @other.id ].sort, Game::Market::WantingPlayers.call(@common.id)
    assert_equal [ @other.id ], Game::Market::WantingPlayers.call(rare_edition.id)
  end

  test "a banned player whose rows remain and the given player are skipped, a player wanting twice counted once" do
    want(@player, "goal")
    want(@player, "order", [ 1 ])
    want(accounts_players(:banned), "goal")
    want(@other, "goal")

    assert_equal [ @player.id ], Game::Market::WantingPlayers.call(@common.id, except: @other.id)
  end

  test "an unknown card season is wanted by nobody" do
    assert_empty Game::Market::WantingPlayers.call(0)
  end
end
