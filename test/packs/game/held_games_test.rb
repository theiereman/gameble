require "test_helper"

class Game::HeldGamesTest < ActiveSupport::TestCase
  setup do
    @player = accounts_players(:player)
    @season_two = Catalog::Season.create!(status: :published, number: 2, published_at: Time.current)
  end

  def edition(name, rarity:)
    one = catalog_card_seasons(name)
    Catalog::CardSeason.insert_all!([ { card_id: one.card_id, season_id: @season_two.id, prestige_score: one.prestige_score, rating: one.rating,
      rarity:, number: one.number } ], returning: :id).rows.flatten.sole
  end

  def hold(card_season_id, quantity = 1, player: @player) = Game::Holding.create!(player_id: player.id, card_season_id:, quantity:)

  test "a game held in two editions is one game, at its best rarity" do
    rare_two = edition(:rare_card_one, rarity: "legendary")
    hold(catalog_card_seasons(:rare_card_one).id)
    hold(rare_two)

    assert_equal({ catalog_cards(:rare_card).id => Catalog::Rarity::TIERS.key(:legendary) }, Game::HeldGames.call(@player.id))
  end

  test "an edition held with no copy left counts for nothing" do
    portal_two = edition(:portal_one, rarity: "legendary")
    hold(catalog_card_seasons(:portal_one).id, 2)
    hold(portal_two, 0)
    hold(catalog_card_seasons(:common_card_one).id, 0)

    assert_equal({ catalog_cards(:portal).id => Catalog::Rarity::TIERS.key(:epic) }, Game::HeldGames.call(@player.id))
  end

  test "card ids narrow the answer; none asked is an empty answer; another player's cards never count" do
    hold(catalog_card_seasons(:portal_one).id)
    hold(catalog_card_seasons(:common_card_one).id)
    hold(catalog_card_seasons(:rare_card_one).id, player: accounts_players(:moderator))
    portal, rare = catalog_cards(:portal).id, catalog_cards(:rare_card).id

    assert_equal [ portal ], Game::HeldGames.call(@player.id, card_ids: [ portal, rare ]).keys
    assert_equal({}, Game::HeldGames.call(@player.id, card_ids: []))
  end
end
