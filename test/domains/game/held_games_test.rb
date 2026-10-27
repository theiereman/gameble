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

  def gained(card_season_id, quantity, at) = Game::Holding.create!(player_id: @player.id, card_season_id:, quantity:, last_gained_at: at)

  test "each game's best held edition: highest rarity, then the season asked, then the latest; copies over every edition, in one query" do
    rare_two = edition(:rare_card_one, rarity: "legendary")
    portal_two = edition(:portal_one, rarity: "epic")
    hold(catalog_card_seasons(:rare_card_one).id, 1)
    hold(rare_two, 2)
    hold(catalog_card_seasons(:portal_one).id, 1)
    hold(portal_two, 3)
    rare, portal, common = catalog_cards(:rare_card).id, catalog_cards(:portal).id, catalog_cards(:common_card).id
    season = catalog_seasons(:one)

    editions = nil
    assert_queries_count(1) { editions = Game::HeldGames.editions(@player, card_ids: [ rare, portal, common ], season:) }

    assert_equal({ rare => Game::HeldGames::Edition.new(card_season_id: rare_two, copies: 3, new: false, editions: 2, gained_at: nil),
      portal => Game::HeldGames::Edition.new(card_season_id: catalog_card_seasons(:portal_one).id, copies: 4, new: false, editions: 2, gained_at: nil) },
      editions)
    assert_equal portal_two, Game::HeldGames.editions(@player, card_ids: [ portal ], season: @season_two).fetch(portal).card_season_id
  end

  test "a game is new when any of its editions was gained after the watermark; an edition with no copy left counts for nothing" do
    Game::PlayerState.find_by!(player_id: @player.id).update_columns(collection_seen_up_to: 1.hour.ago)
    portal_two = edition(:portal_one, rarity: "legendary")
    gained(catalog_card_seasons(:portal_one).id, 1, 1.minute.ago)
    gained(portal_two, 1, 2.hours.ago)
    gained(catalog_card_seasons(:rare_card_one).id, 1, 2.hours.ago)
    gained(edition(:rare_card_one, rarity: "legendary"), 0, 1.minute.ago)
    portal, rare = catalog_cards(:portal).id, catalog_cards(:rare_card).id

    editions = Game::HeldGames.editions(@player, card_ids: [ portal, rare ], season: catalog_seasons(:one))

    assert_equal [ portal_two, 2, true, 2 ], editions.fetch(portal).to_h.values_at(:card_season_id, :copies, :new, :editions)
    assert_in_delta 1.minute.ago, editions.fetch(portal).gained_at, 5
    assert_equal [ catalog_card_seasons(:rare_card_one).id, 1, false, 1 ], editions.fetch(rare).to_h.values_at(:card_season_id, :copies, :new, :editions)
  end

  test "a visitor or no card asked costs no query; another player's copies never count" do
    hold(catalog_card_seasons(:portal_one).id, 1, player: accounts_players(:moderator))
    portal = catalog_cards(:portal).id
    season = catalog_seasons(:one)

    assert_queries_count(0) do
      assert_equal({}, Game::HeldGames.editions(nil, card_ids: [ portal ], season:))
      assert_equal({}, Game::HeldGames.editions(@player, card_ids: [], season:))
    end
    assert_equal({}, Game::HeldGames.editions(@player, card_ids: [ portal ], season:))
  end

  test "the games held, and how many at each best rarity, every tier a key, in one query each" do
    hold(catalog_card_seasons(:rare_card_one).id, 2)
    hold(edition(:rare_card_one, rarity: "epic"))
    hold(catalog_card_seasons(:portal_one).id)
    hold(catalog_card_seasons(:common_card_one).id, 3)
    hold(catalog_card_seasons(:legendary_card_one).id, 0)
    hold(catalog_card_seasons(:uncommon_card_one).id, player: accounts_players(:moderator))

    assert_queries_count(1) { assert_equal 3, Game::HeldGames.count(@player) }
    by_rarity = nil
    assert_queries_count(1) { by_rarity = Game::HeldGames.by_rarity(@player) }
    assert_equal({ 1 => 1, 2 => 0, 3 => 0, 4 => 2, 5 => 0 }, by_rarity)
  end

  test "a visitor holds no game, without a query" do
    assert_queries_count(0) do
      assert_equal 0, Game::HeldGames.count(nil)
      assert_equal({ 1 => 0, 2 => 0, 3 => 0, 4 => 0, 5 => 0 }, Game::HeldGames.by_rarity(nil))
    end
  end
end
