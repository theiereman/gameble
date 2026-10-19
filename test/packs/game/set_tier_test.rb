require "test_helper"
require_relative "../../support/catalog_seeds"
require_relative "../../support/game_packs"

class Game::SetTierTest < ActiveSupport::TestCase
  include CatalogSeeds
  include GamePacks

  setup do
    Game::DrawPool.reset!
    @player = accounts_players(:player)
    @other = accounts_players(:moderator)
    @common, @uncommon, @rare, @portal, @legendary = fixture_tier_ids
    @season = catalog_seasons(:one)
  end

  # A set of `season` holding `members`, asking `tiers` ({ tier => required }); its id.
  def insert_set(members, tiers, kind: "theme", key: "roguelike", params: { "theme" => "roguelike" }, season: @season)
    set_id = Catalog::Set.insert_all!([ { season_id: season.id, kind:, key:, params: } ], returning: :id).rows.flatten.sole
    Catalog::SetMembership.insert_all!(members.each_with_index.map { |id, index| { set_id:, card_season_id: id, position: index + 1 } })
    Catalog::SetTier.insert_all!(tiers.map { |tier, required| { set_id:, tier: tier.to_s, required: } }) if tiers.any?
    set_id
  end

  # More common card-seasons in the fixture season, drawable; their ids.
  def more_commons(count)
    seed_card_seasons(Array.new(count) { 0.1 + (it * 0.001) }, season: @season)
    ids = Catalog::CardSeason.where(season_id: @season.id, rarity: nil).order(:id).ids
    Catalog::CardSeason.where(id: ids).update_all(rarity: 1)
    ids
  end

  # Season 2, published: the fixture cards again at their rarities; the
  # season and its card-seasons in fixture_tier_ids order.
  def publish_season_two
    season = Catalog::Season.create!(status: :published, number: 2, published_at: Time.current)
    rows = %i[common_card_one uncommon_card_one rare_card_one portal_one legendary_card_one].map do |name|
      one = catalog_card_seasons(name)
      { card_id: one.card_id, season_id: season.id, prestige_score: one.prestige_score, rating: one.rating, rarity: one.rarity, number: one.number }
    end
    [ season, Catalog::CardSeason.insert_all!(rows, returning: :id).rows.flatten ]
  end

  def hold(player, card_season_id, quantity = 1) = Game::Holding.create!(player_id: player.id, card_season_id:, quantity:)

  def open_pack(player, cards, season: @season, idempotency_key: nil)
    create_pack(player, cards:, season:)
    Game::OpenPack.new.call(player:, idempotency_key:).value!
  end

  def tiers(player) = Game::SetTier.where(player_id: player.id).order(:id).pluck(:set_id, :tier, :reached_by, :pack_id)
  def tier_events(player) = game_events(player).select { it.is_a?(Game::SetTierReached) || it.is_a?(Game::SetCompleted) }

  def refused(error, &block)
    assert_raises(error) { ActiveRecord::Base.transaction(requires_new: true, &block) }
  end

  def befriend(first, second)
    low, high = [ first.id, second.id ].minmax
    Game::Friendship.create!(low_player_id: low, high_player_id: high)
  end

  test "an opening that crosses a theme's bronze records it, publishes SetTierReached after the opening and answers it" do
    theme = insert_set([ @common, @uncommon, @rare, @legendary, *more_commons(16) ], { bronze: 2, silver: 5, gold: 10, complete: 20 })
    hold(@player, @rare)

    pack = open_pack(@player, [ @common ] * 5)

    assert_equal [ [ theme, "bronze", "pack", pack.id ] ], tiers(@player)
    assert_equal [ Game::PackOpened, Game::SetTierReached ], game_events(@player).last(2).map(&:class)
    assert_equal({ player_id: @player.id, set_id: theme, tier: "bronze" }, game_events(@player, Game::SetTierReached).sole.data)
    assert_equal [ [ "theme", "roguelike", { "theme" => "roguelike" }, "bronze", 2, 20, [ [ "bronze", 2 ], [ "silver", 5 ], [ "gold", 10 ] ] ] ],
      Game::PackSetTiers.call(pack).map(&:deconstruct)
  end

  test "a tier crossed already is not reached again: no row, no event, nothing answered" do
    insert_set([ @common, @uncommon, @rare, @legendary ], { bronze: 2, silver: 4, gold: 4, complete: 4 })
    hold(@player, @rare)
    open_pack(@player, [ @common ] * 5)

    pack = open_pack(@player, [ @uncommon ] * 5)

    assert_equal [ "bronze" ], tiers(@player).map(&:second)
    assert_equal 1, tier_events(@player).size
    assert_empty Game::PackSetTiers.call(pack)
  end

  test "several tiers reached at once are each recorded and published, bronze before silver" do
    theme = insert_set([ @common, @uncommon, @rare ], { bronze: 1, silver: 1, gold: 2, complete: 3 })

    pack = open_pack(@player, [ @common ] * 5)

    assert_equal [ [ theme, "bronze", "pack", pack.id ], [ theme, "silver", "pack", pack.id ] ], tiers(@player)
    assert_equal [ "bronze", "silver" ], tier_events(@player).map { it.data[:tier] }
    assert_equal %w[bronze silver], Game::PackSetTiers.call(pack).map(&:tier)
  end

  test "an opening crossing a ranked set's tiers records them by the count they ask, a SetTierReached for each rank and SetCompleted for complete" do
    members = [ @common, @uncommon, @rare, @legendary, *more_commons(16) ]
    theme = insert_set(members, Catalog::TierTable.tiers(members.size))
    members.first(15).each { hold(@player, it) }

    pack = open_pack(@player, members.last(5))

    assert_equal %w[adept expert master complete].map { [ theme, it, "pack", pack.id ] }, tiers(@player)
    assert_equal [ Game::SetTierReached, Game::SetTierReached, Game::SetTierReached, Game::SetCompleted ], tier_events(@player).map(&:class)
    assert_equal %w[adept expert master], game_events(@player, Game::SetTierReached).map { it.data[:tier] }
    answered = Game::PackSetTiers.call(pack)
    assert_equal [ [ "adept", 5 ], [ "expert", 10 ], [ "master", 15 ], [ "complete", 20 ] ], answered.map { [ it.tier, it.required ] }
    assert_equal [ [ [ "adept", 5 ], [ "expert", 10 ], [ "master", 15 ] ] ], answered.map(&:thresholds).uniq
  end

  test "the database takes every tier of both families and refuses an unknown one" do
    pack = create_pack(@player, opened_at: Time.current)
    rows = Game::SetTier::TIERS.map do |tier|
      { player_id: @player.id, set_id: catalog_sets(:valve_one).id, tier:, reached_by: "pack", pack_id: pack.id, reached_at: Time.current }
    end

    assert_equal Game::SetTier::TIERS.size, Game::SetTier.insert_all!(rows).length
    refused(ActiveRecord::CheckViolation) { Game::SetTier.insert_all!([ rows.first.merge(tier: "platinum", player_id: @other.id) ]) }
  end

  test "the last card of a franchise completes it: one complete row and SetCompleted" do
    franchise = insert_set([ @common, @uncommon ], { complete: 2 }, kind: "franchise", key: "dark-souls", params: { "franchise" => "Dark Souls" })
    hold(@player, @common)

    pack = open_pack(@player, [ @uncommon ] * 5)

    assert_equal [ [ franchise, "complete", "pack", pack.id ] ], tiers(@player)
    assert_equal [ Game::SetCompleted ], tier_events(@player).map(&:class)
    assert_equal({ player_id: @player.id, set_id: franchise }, tier_events(@player).sole.data)
  end

  test "a theme's last card after its gold completes it alone" do
    theme = insert_set([ @common, @uncommon, @rare ], { bronze: 1, silver: 1, gold: 2, complete: 3 })
    open_pack(@player, [ @common ] * 5)
    open_pack(@player, [ @uncommon ] * 5)
    assert_equal %w[bronze silver gold], tiers(@player).map(&:second)

    pack = open_pack(@player, [ @rare ] * 5)

    assert_equal [ [ theme, "complete" ] ], Game::SetTier.where(pack_id: pack.id).pluck(:set_id, :tier)
    assert_equal [ Game::SetCompleted ], tier_events(@player).last(1).map(&:class)
    assert_equal 4, tier_events(@player).size
  end

  test "a game held only in an earlier edition counts toward the published season's sets; earlier seasons' sets earn nothing" do
    insert_set([ @common, @rare ], { bronze: 1, complete: 2 }, key: "rpg", params: { "theme" => "rpg" })
    hold(@player, @rare)
    season_two, (common_two, uncommon_two, rare_two, *) = publish_season_two
    theme = insert_set([ common_two, uncommon_two, rare_two ], { bronze: 2, complete: 3 }, season: season_two)

    pack = open_pack(@player, [ common_two ] * 5, season: season_two)

    assert_equal [ [ theme, "bronze", "pack", pack.id ] ], tiers(@player)
  end

  test "an accepted trade that brings an earlier edition across a published theme's bronze records it for the player who gains it" do
    season_two, (common_two, uncommon_two, rare_two, _portal_two, legendary_two) = publish_season_two
    theme = insert_set([ common_two, uncommon_two, rare_two ], { bronze: 2, complete: 3 }, season: season_two)
    befriend(@player, @other)
    hold(@player, common_two)
    hold(@player, legendary_two)
    hold(@other, @rare)

    trade = Game::ProposeTrade.new.call(player: @other, recipient: @player, offer: { @rare => 1 }, request: { legendary_two => 1 }).value!
    Game::AcceptTrade.new.call(player: @player, trade_id: trade.id, revision: Game::Trade.find(trade.id).revision).value!

    assert_equal [ [ theme, "bronze", "trade", nil ] ], tiers(@player)
    assert_equal [ Game::TradeAccepted, Game::SetTierReached ], Rails.configuration.event_store.read.to_a.last(2).map(&:class)
    assert_equal({ player_id: @player.id, set_id: theme, tier: "bronze" }, tier_events(@player).sole.data)
    assert_empty tiers(@other)
  end

  test "a replayed opening publishes nothing and answers the same tiers" do
    insert_set([ @common, @uncommon, @rare ], { bronze: 1, silver: 1, gold: 2, complete: 3 })
    key = SecureRandom.uuid
    pack = open_pack(@player, [ @common ] * 5, idempotency_key: key)
    answered = Game::PackSetTiers.call(pack)

    assert_no_difference -> { game_events(@player).size + Game::SetTier.count } do
      Game::OpenPack.new.call(player: @player, idempotency_key: key).value!
    end
    assert_equal answered, Game::PackSetTiers.call(pack)
  end

  test "a set with no tier rows earns nothing" do
    insert_set([ @common ], {})

    pack = open_pack(@player, [ @common ] * 5)

    assert_empty tiers(@player)
    assert_empty Game::PackSetTiers.call(pack)
  end

  test "with no season published, an opening reaches no tier" do
    insert_set([ @common ], { bronze: 1, complete: 1 })
    create_pack(@player, cards: [ @common ] * 5)

    without_published_season { Game::OpenPack.new.call(player: @player).value! }

    assert_empty tiers(@player)
  end

  test "a reached tier stays reached when its cards leave" do
    theme = insert_set([ @common, @uncommon ], { bronze: 1, complete: 2 })
    open_pack(@player, [ @common ] * 5)
    Game::Holding.where(player_id: @player.id).update_all(quantity: 0)

    open_pack(@player, [ @common ] * 5)

    assert_equal [ [ theme, "bronze" ] ], tiers(@player).map { it.first(2) }
    assert_equal 1, tier_events(@player).size
  end

  test "the database takes a tier once per player and set, a known tier, and a pack exactly when reached by an opening" do
    pack = create_pack(@player, opened_at: Time.current)
    row = { player_id: @player.id, set_id: catalog_sets(:valve_one).id, tier: "gold", reached_by: "pack", pack_id: pack.id, reached_at: Time.current }
    Game::SetTier.insert_all!([ row ])

    refused(ActiveRecord::RecordNotUnique) { Game::SetTier.insert_all!([ row ]) }
    refused(ActiveRecord::CheckViolation) { Game::SetTier.insert_all!([ row.merge(tier: "platinum") ]) }
    refused(ActiveRecord::CheckViolation) { Game::SetTier.insert_all!([ row.merge(tier: "bronze", reached_by: "gift") ]) }
    refused(ActiveRecord::CheckViolation) { Game::SetTier.insert_all!([ row.merge(tier: "bronze", pack_id: nil) ]) }
    refused(ActiveRecord::CheckViolation) { Game::SetTier.insert_all!([ row.merge(tier: "bronze", reached_by: "trade") ]) }
  end
end
