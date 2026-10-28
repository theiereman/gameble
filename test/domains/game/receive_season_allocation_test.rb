require "test_helper"
require_relative "../../support/catalog_seeds"
require_relative "../../support/game_packs"
require_relative "../../support/game_trades"
require_relative "../../support/holdings"

class Game::ReceiveSeasonAllocationTest < ActiveSupport::TestCase
  include Holdings
  include CatalogSeeds
  include GamePacks
  include GameTrades

  setup do
    @player = accounts_players(:player)
    @friend = accounts_players(:moderator)
    @common, @uncommon, @rare, @portal, @legendary = fixture_tier_ids
    @held_before = [ @common, @uncommon, @rare ]
    @season_two, @cards_two = publish_season_two
    @set = Catalog::Set.insert_all!([ { season_id: @season_two.id, kind: "theme", key: "roguelike", params: { "theme" => "roguelike" } } ], returning: :id).rows.flatten.sole
    Catalog::SetMembership.insert_all!(@cards_two.each_with_index.map { |id, index| { set_id: @set, card_season_id: id, position: index + 1 } })
    Catalog::SetTier.insert_all!({ novice: 1, apprentice: 2, adept: 3, complete: 5 }.map { |tier, required| { set_id: @set, tier: tier.to_s, required: } })
    @held_before.each { hold(@player, it) }
    Game::PlayerState.where(player_id: [ @player.id, @friend.id ]).update_all(allocation_received_season: 1, allocation_seen_season: 1)
  end

  def publish_season_two
    season = Catalog::Season.create!(status: :published, number: 2, published_at: Time.current)
    rows = %i[common_card_one uncommon_card_one rare_card_one portal_one legendary_card_one].map do |name|
      one = catalog_card_seasons(name)
      { card_id: one.card_id, season_id: season.id, prestige_score: one.prestige_score, rating: one.rating, rarity: one.rarity, number: one.number }
    end
    [ season, Catalog::CardSeason.insert_all!(rows, returning: :id).rows.flatten ]
  end

  def tiers(player) = Game::SetTier.where(player_id: player.id).order(:id).pluck(:tier, :reached_by, :pack_id)
  def tier_events(player) = game_events(player).select { it.is_a?(Game::SetTierReached) || it.is_a?(Game::SetCompleted) }
  def state(player) = Game::PlayerState.find_by!(player_id: player.id)

  test "the receipt records the tiers the player already meets as an allocation, with one event and no tier event" do
    carried = Game::ReceiveSeasonAllocation.new.call(player: @player).value!

    assert_equal [ [ @set, "novice" ], [ @set, "apprentice" ], [ @set, "adept" ] ], carried
    assert_equal [ [ "novice", "allocation", nil ], [ "apprentice", "allocation", nil ], [ "adept", "allocation", nil ] ], tiers(@player)
    assert_equal 2, state(@player).allocation_received_season
    assert_equal 1, state(@player).allocation_seen_season
    assert_empty tier_events(@player)
    assert_equal [ 2 ], game_events(@player, Game::SeasonAllocationReceived).map { it.data.fetch(:season_number) }
  end

  test "a second receipt writes nothing" do
    Game::ReceiveSeasonAllocation.new.call(player: @player).value!

    assert_no_difference -> { Game::SetTier.count } do
      assert_empty Game::ReceiveSeasonAllocation.new.call(player: @player).value!
    end
    assert_equal 1, game_events(@player, Game::SeasonAllocationReceived).size
  end

  test "a player holding nothing receives no tier but the season is recorded" do
    Game::Holding.where(player_id: @player.id).delete_all

    assert_empty Game::ReceiveSeasonAllocation.new.call(player: @player).value!
    assert_empty tiers(@player)
    assert_equal 2, state(@player).allocation_received_season
  end

  test "an opening receives the allocation first and celebrates only the tiers it crosses" do
    create_pack(@player, cards: [ @portal, @legendary, @portal, @portal, @portal ], season: @season_two)

    Game::OpenPack.new.call(player: @player).value!

    assert_equal [ [ "novice", "allocation" ], [ "apprentice", "allocation" ], [ "adept", "allocation" ] ], tiers(@player).first(3).map { it.first(2) }
    assert_equal [ "complete" ], Game::SetTier.where(player_id: @player.id, reached_by: "pack").pluck(:tier)
    assert_equal [ Game::SetCompleted ], tier_events(@player).map(&:class)
  end

  test "an accepted trade receives the allocation of both players without a tier event" do
    conclude_trade(@player, @friend, offer: { @portal => 1 }, request: { @legendary => 1 })

    assert_equal [ 2, 2 ], [ @player, @friend ].map { state(it).allocation_received_season }
    assert_empty Game::SetTier.where(reached_by: "allocation").where.not(player_id: [ @player.id, @friend.id ]).to_a
    assert_empty tier_events(@player)
    assert_empty Game::FeedEntry.where(player_id: @player.id, kind: "set").to_a
  end

  test "a new account starts at the published season" do
    administrator = accounts_players(:administrator)
    Game::PlayerState.where(player_id: administrator.id).delete_all

    created = Game::CreatePlayerState.new.call(player: administrator).value!

    assert_equal [ 2, 2 ], [ created.allocation_received_season, created.allocation_seen_season ]
  end
end
