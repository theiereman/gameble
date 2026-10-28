require "test_helper"
require_relative "../../support/catalog_seeds"
require_relative "../../support/game_packs"
require_relative "../../support/holdings"
require_relative "../../support/lock_races"

# The allocation of a newly published season, received by an opening and by an
# accepted trade of the same player at once: whichever runs first receives
# it, the other finds it received. Each thread has its own connection, so the
# test commits for real and cleans up after itself.
class Game::ReceiveSeasonAllocationRacesTest < ActiveSupport::TestCase
  include Holdings
  include CatalogSeeds
  include GamePacks
  include LockRaces

  self.use_transactional_tests = false

  setup do
    @alice = accounts_players(:player)
    @bob = accounts_players(:moderator)
    @common, @uncommon, @rare, @portal, @legendary = fixture_tier_ids
    @season_two = Catalog::Season.create!(status: :published, number: 2, published_at: Time.current)
    @cards_two = season_two_cards
    @set = Catalog::Set.insert_all!([ { season_id: @season_two.id, kind: "theme", key: "roguelike", params: { "theme" => "roguelike" } } ], returning: :id).rows.flatten.sole
    Catalog::SetMembership.insert_all!(@cards_two.each_with_index.map { |id, index| { set_id: @set, card_season_id: id, position: index + 1 } })
    Catalog::SetTier.insert_all!({ novice: 1, apprentice: 2, adept: 3, complete: 5 }.map { |tier, required| { set_id: @set, tier: tier.to_s, required: } })
    [ @common, @uncommon, @rare ].each { hold(@alice, it) }
    hold(@alice, @portal)
    hold(@bob, @legendary)
    low, high = [ @alice.id, @bob.id ].minmax
    Game::Friendship.create!(low_player_id: low, high_player_id: high)
    Game::PlayerState.where(player_id: [ @alice.id, @bob.id ]).update_all(allocation_received_season: 1, allocation_seen_season: 1)
  end

  teardown do
    players = [ @alice.id, @bob.id ]
    trades = Game::Trade.where(proposer_id: players).or(Game::Trade.where(recipient_id: players))
    Game::FeedEntry.where(trade_id: trades.select(:id)).delete_all
    Game::TradeItem.where(trade_id: trades.select(:id)).delete_all
    trades.delete_all
    Game::Friendship.where(low_player_id: players).or(Game::Friendship.where(high_player_id: players)).delete_all
    Game::FirstDiscovery.where(pack_id: Game::Pack.where(player_id: players).select(:id)).delete_all
    [ Game::Holding, Game::FeedEntry, Game::SetTier, Game::Pack ].each { |model| model.where(player_id: players).delete_all }
    Game::PlayerState.where(player_id: players).update_all(allocation_received_season: 1, allocation_seen_season: 1)
    Catalog::SetMembership.where(set_id: @set).delete_all
    Catalog::SetTier.where(set_id: @set).delete_all
    Catalog::Set.where(id: @set).delete_all
    Catalog::CardSeason.where(season_id: @season_two.id).delete_all
    Catalog::Season.where(id: @season_two.id).delete_all
    streams = players.map { |id| Game::Operation.stream_name(id) }
    connection = ActiveRecord::Base.connection
    event_ids = connection.select_values(ActiveRecord::Base.sanitize_sql_array([ "SELECT event_id FROM event_store_events_in_streams WHERE stream IN (?)", streams ]))
    connection.exec_delete(ActiveRecord::Base.sanitize_sql_array([ "DELETE FROM event_store_events_in_streams WHERE stream IN (?)", streams ]))
    connection.exec_delete(ActiveRecord::Base.sanitize_sql_array([ "DELETE FROM event_store_events WHERE event_id IN (?)", event_ids ])) if event_ids.any?
  end

  def season_two_cards
    rows = %i[common_card_one uncommon_card_one rare_card_one portal_one legendary_card_one].map do |name|
      one = catalog_card_seasons(name)
      { card_id: one.card_id, season_id: @season_two.id, prestige_score: one.prestige_score, rating: one.rating, rarity: one.rarity, number: one.number }
    end
    Catalog::CardSeason.insert_all!(rows, returning: :id).rows.flatten
  end

  def received(player) = Rails.configuration.event_store.read.stream(Game::Operation.stream_name(player.id)).of_type([ Game::SeasonAllocationReceived ]).count
  def allocation_tiers(player) = Game::SetTier.where(player_id: player.id, reached_by: "allocation").order(:id).pluck(:tier)
  def marker(player) = Game::PlayerState.find_by!(player_id: player.id).allocation_received_season

  test "an opening and an accepted trade of the same player at once receive the allocation once" do
    create_pack(@alice, cards: Array.new(Game::Pack::SIZE, @portal), season: @season_two)
    trade = Game::ProposeTrade.new.call(player: @alice, recipient: @bob, offer: { @portal => 1 }, request: { @legendary => 1 }).value!

    results = together(
      -> { Game::OpenPack.new.call(player: Accounts::Player.find(@alice.id)) },
      -> { Game::AcceptTrade.new.call(player: Accounts::Player.find(@bob.id), trade_id: trade.id, revision: trade.revision) }
    )

    assert results.all?(&:success?), results.inspect
    assert_equal 1, received(@alice)
    assert_equal 1, received(@bob)
    assert_equal %w[novice apprentice adept], allocation_tiers(@alice)
    assert_equal 2, marker(@alice)
    assert_equal 2, marker(@bob)
  end

  test "two openings of the same player at once receive the allocation once" do
    2.times { create_pack(@alice, cards: Array.new(Game::Pack::SIZE, @portal), season: @season_two) }

    results = together(
      -> { Game::OpenPack.new.call(player: Accounts::Player.find(@alice.id)) },
      -> { Game::OpenPack.new.call(player: Accounts::Player.find(@alice.id)) }
    )

    assert results.all?(&:success?), results.inspect
    assert_equal 1, received(@alice)
    assert_equal %w[novice apprentice adept], allocation_tiers(@alice)
    assert_equal 2, marker(@alice)
  end
end
