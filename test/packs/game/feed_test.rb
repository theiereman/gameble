require "test_helper"
require_relative "../../support/game_packs"
require_relative "../../support/game_trades"
require_relative "../../support/game_sets"
require_relative "../../support/catalog_seeds"

class Game::FeedTest < ActiveSupport::TestCase
  include GamePacks
  include GameTrades
  include GameSets
  include CatalogSeeds

  setup do
    @player = accounts_players(:player)
    @other = accounts_players(:moderator)
  end

  def open_pack(player, cards)
    cards += [ fixture_tier_ids[0] ] * 4 if cards.size == 1
    create_pack(player, cards:)
    Game::OpenPack.new.call(player:).value!
  end

  # The opening's card entries, without the set entry of a set it reaches.
  def entries = Game::FeedEntry.where.not(kind: "set").order(:id).pluck(:position, :notable, :rarity)

  def trade_cards(proposer, recipient, offer: { fixture_tier_ids[3] => 1 }, request: { fixture_tier_ids[2] => 1 })
    conclude_trade(proposer, recipient, offer:, request:)
  end

  # Feed rows of `kind` written straight, newest last: pulls and discoveries
  # on a pack of `player`, reposts with none.
  def add_entries(player, count, kind: "pull", notable: true, from: 1.hour.ago)
    pack = create_pack(player) if %w[pull discovery].include?(kind)
    rows = Array.new(count) do |index|
      at = from + index.seconds
      { kind:, player_id: player.id, pack_id: pack&.id, card_season_id: fixture_tier_ids[3], position: (index if pack),
        rarity: 4, notable:, occurred_at: at, created_at: at, updated_at: at }
    end
    Game::FeedEntry.insert_all!(rows)
  end

  test "each pull of Épique or better is an entry, the others are not" do
    common, _, rare, epic, legendary = fixture_tier_ids

    pack = open_pack(@player, [ common, epic, rare, legendary, common ])

    assert_equal [ [ 1, true, 4 ], [ 3, true, 5 ] ], entries
    assert_equal [ pack.id ], Game::FeedEntry.where(kind: "pull").pluck(:pack_id).uniq
    assert_equal [ @player.id ], Game::FeedEntry.pluck(:player_id).uniq
  end

  test "a pack with no notable pull leaves its best card as a filler" do
    common, uncommon, rare, = fixture_tier_ids

    open_pack(@player, [ common, rare, uncommon, rare, common ])

    assert_equal [ [ 1, false, 3 ] ], entries
  end

  test "the same event handled twice adds nothing and never fails" do
    open_pack(@player, [ fixture_tier_ids[4] ] * 5)
    event = game_events(@player, Game::PackOpened).last

    assert_no_difference -> { Game::FeedEntry.count } do
      Game::Handlers::PackOpenedFeed.call(event)
    end
    assert_equal 5, Game::FeedEntry.count
  end

  test "an opening publishes its own event only, the feed handler publishes nothing" do
    # A card already discovered and in no set: no other event follows.
    create_pack(@player, cards: [ fixture_tier_ids[4] ] * 5)
    before = game_events(@player).size

    Game::OpenPack.new.call(player: @player).value!

    assert_equal before + 1, game_events(@player).size
  end

  test "a visitor reads the entries newest first" do
    legendary = fixture_tier_ids[4]
    travel_to(2.hours.ago) { open_pack(@player, [ legendary ]) }
    travel_to(1.hour.ago) { open_pack(@other, [ legendary ]) }

    shown = Game::FeedEntries.call(nil)

    assert_equal [ @other, @player ], shown.map(&:player)
    assert shown.none?(&:filler)
  end

  test "an entry of a private, friends only or banned player is hidden from a visitor" do
    legendary = fixture_tier_ids[4]
    open_pack(@player, [ legendary ])
    open_pack(@other, [ legendary ])

    @other.update!(visibility: :private)
    assert_equal [ @player ], Game::FeedEntries.call(nil).map(&:player)

    @other.update!(visibility: :friends_only)
    assert_equal [ @player ], Game::FeedEntries.call(nil).map(&:player)

    @other.update!(visibility: :public)
    @player.update!(banned_at: Time.current)
    assert_equal [ @other ], Game::FeedEntries.call(nil).map(&:player)
  end

  test "a friends-only player's entries show to their friends only, asked once per player" do
    add_entries(@other, 5)
    @other.update!(visibility: :friends_only)
    stranger = accounts_players(:administrator)
    Game::Friendship.create!(low_player_id: [ @player.id, @other.id ].min, high_player_id: [ @player.id, @other.id ].max)

    # The notable rows, their player, one friendship question (not one per
    # entry), then the fillers' rows.
    shown = nil
    assert_queries_count(4) { shown = Game::FeedEntries.call(@player) }
    assert_equal [ @other ] * 5, shown.map(&:player)
    assert_empty Game::FeedEntries.call(stranger)
    assert_empty Game::FeedEntries.call(nil)
  end

  test "staff read the feed as a player does: a private or banned player's entries stay hidden" do
    legendary = fixture_tier_ids[4]
    open_pack(@player, [ legendary ])
    open_pack(@other, [ legendary ])
    @player.update!(visibility: :private)

    assert_equal [ @other ], Game::FeedEntries.call(accounts_players(:administrator)).map(&:player)

    @player.update!(visibility: :public, banned_at: Time.current)
    assert_equal [ @other ], Game::FeedEntries.call(accounts_players(:administrator)).map(&:player)
  end

  test "lower rarities stay out while the feed holds enough, and fill it when it is quiet" do
    common = fixture_tier_ids[0]
    legendary = fixture_tier_ids[4]
    travel_to(3.hours.ago) { open_pack(@player, [ common ] * 5) }
    open_pack(@other, [ legendary ])

    quiet = Game::FeedEntries.call(nil)
    assert_equal [ true, false ], quiet.map(&:filler).sort_by { |filler| filler ? 0 : 1 }
    assert_equal [ @other, @player ], quiet.map(&:player)

    Game::FeedEntries::MIN.times { open_pack(@other, [ legendary ]) }
    assert Game::FeedEntries.call(nil).none?(&:filler)
  end

  test "an empty feed is empty" do
    assert_empty Game::FeedEntries.call(nil)
  end

  test "an opening writes pulls" do
    open_pack(@player, [ fixture_tier_ids[4] ])

    assert_equal [ "pull" ], Game::FeedEntry.distinct.pluck(:kind)
  end

  test "a kind shows only its entries, the whole feed shows every kind" do
    open_pack(@player, [ fixture_tier_ids[3] ])
    trade_cards(@other, accounts_players(:administrator))
    add_entries(@other, 2, kind: "repost")

    assert_equal [ "trade" ], Game::FeedEntries.call(nil, kind: "trade").map { |item| item.entry.kind }
    assert_equal [ "pull" ], Game::FeedEntries.call(nil, kind: "pull").map { |item| item.entry.kind }
    assert_equal %w[repost repost], Game::FeedEntries.call(nil, kind: "repost").map { |item| item.entry.kind }
    assert_equal %w[pull repost set trade], Game::FeedEntries.call(nil).map { |item| item.entry.kind }.uniq.sort
    assert_empty Game::FeedEntries.call(nil, kind: "discovery")
  end

  test "fillers complete the whole feed and the pulls, never another kind" do
    open_pack(@player, [ fixture_tier_ids[0] ] * 5)

    assert_equal [ true ], Game::FeedEntries.call(nil).map(&:filler)
    assert_equal [ true ], Game::FeedEntries.call(nil, kind: "pull").map(&:filler)
    %w[discovery trade repost].each { |kind| assert_empty Game::FeedEntries.call(nil, kind:) }
  end

  test "a hidden or banned player's crowd of entries does not hide an older visible one" do
    travel_to(3.hours.ago) { open_pack(@player, [ fixture_tier_ids[3] ]) }
    add_entries(@other, Game::FeedEntries::WINDOW + 5)

    @other.update!(visibility: :private)
    assert_equal [ @player ], Game::FeedEntries.call(nil).map(&:player).uniq

    @other.update!(visibility: :public, banned_at: Time.current)
    assert_equal [ @player ], Game::FeedEntries.call(nil, kind: "pull").map(&:player).uniq
  end

  test "a hidden crowd of fillers does not hide an older visible filler" do
    travel_to(3.hours.ago) { open_pack(@player, [ fixture_tier_ids[0] ] * 5) }
    add_entries(@other, Game::FeedEntries::WINDOW + 5, notable: false)
    @other.update!(visibility: :private)

    shown = Game::FeedEntries.call(nil)

    assert_equal [ @player ], shown.map(&:player)
    assert shown.all?(&:filler)
  end

  test "players restricts the notable entries to those players, under every kind" do
    stranger = accounts_players(:administrator)
    add_entries(@other, 2)
    trade_cards(@other, stranger)
    add_entries(stranger, 3)
    add_entries(stranger, 1, kind: "repost")

    shown = Game::FeedEntries.call(@player, players: [ @other.id ])

    assert_equal [ @other ], shown.map(&:player).uniq
    assert_equal %w[pull trade], shown.map { |item| item.entry.kind }.uniq.sort
    assert_equal [ @other ], Game::FeedEntries.call(@player, kind: "pull", players: [ @other.id ]).map(&:player).uniq
    assert_empty Game::FeedEntries.call(@player, kind: "repost", players: [ @other.id ])
    assert_empty Game::FeedEntries.call(@player, players: [])
  end

  test "players restricts the fillers too" do
    stranger = accounts_players(:administrator)
    add_entries(@other, 2, notable: false)
    add_entries(stranger, 3, notable: false)

    shown = Game::FeedEntries.call(@player, players: [ @other.id ])

    assert_equal [ @other ] * 2, shown.map(&:player)
    assert shown.all?(&:filler)
    assert_equal [ @other ] * 2, Game::FeedEntries.call(@player, kind: "pull", players: [ @other.id ]).map(&:player)
  end

  test "players keeps Game::Visibility: a private one of them stays hidden" do
    add_entries(@other, 2)
    @other.update!(visibility: :private)

    assert_empty Game::FeedEntries.call(@player, players: [ @other.id ])
  end

  def accepted_trade(proposer, recipient)
    low, high = [ proposer.id, recipient.id ].minmax
    Game::Trade.create!(low_player_id: low, high_player_id: high, proposer_id: proposer.id, recipient_id: recipient.id,
      status: "accepted", proposed_at: 1.hour.ago, expires_at: 1.day.from_now, closed_at: Time.current)
  end

  def kinds(shown) = shown.map { |item| item.entry.kind }

  test "a concluded trade is one entry naming its proposer, its recipient as partner and the best card each gave" do
    common, _, rare, epic, = fixture_tier_ids

    trade = conclude_trade(@player, @other, offer: { common => 2, epic => 1 }, request: { rare => 1 })

    entry = Game::FeedEntry.where(kind: "trade").sole
    assert_equal [ "trade", @player.id, @other.id, trade.id, epic, rare, 4, true, nil, nil ],
      entry.values_at(:kind, :player_id, :partner_id, :trade_id, :card_season_id, :partner_card_season_id, :rarity, :notable,
        :pack_id, :position)
    shown = Game::FeedEntries.call(nil, kind: "trade").sole
    assert_equal [ @player, @other, false ], [ shown.player, shown.partner, shown.filler ]
  end

  test "a side's best card is its highest tier, the lowest card-season id on a tie, and the rarity is the higher side's" do
    common, uncommon, rare, _, legendary = fixture_tier_ids
    low, high = [ uncommon, rare ].sort
    trade = accepted_trade(@player, @other)

    recorded = Game::FeedEntry.record_trade(trade_id: trade.id, proposer_id: @player.id, recipient_id: @other.id,
      offer: [ high, common, low ], request: [ legendary ], rarities: { low => 3, high => 3, common => 1, legendary => 5 }, at: Time.current)

    assert recorded
    assert_equal [ low, legendary, 5 ], Game::FeedEntry.sole.values_at(:card_season_id, :partner_card_season_id, :rarity)
  end

  test "the same trade event handled twice adds no entry, counts the trade once and never fails" do
    conclude_trade(@player, @other, offer: { fixture_tier_ids[3] => 1 }, request: { fixture_tier_ids[2] => 1 })
    event = game_events(@player, Game::TradeAccepted).sole

    assert_no_changes -> { [ Game::FeedEntry.count, Game::WeeklyContribution.order(:player_id).pluck(:player_id, :trades) ] } do
      Game::Handlers::TradeAccepted.call(event)
    end
    assert_equal 1, Game::FeedEntry.where(kind: "trade").count
  end

  test "a trade rolled back leaves no entry and no contribution" do
    ApplicationRecord.transaction do
      conclude_trade(@player, @other, offer: { fixture_tier_ids[3] => 1 }, request: { fixture_tier_ids[2] => 1 })
      raise ActiveRecord::Rollback
    end

    assert_not Game::FeedEntry.exists?
    assert_not Game::WeeklyContribution.exists?
  end

  test "a trade shows only to a viewer who may see both its players" do
    conclude_trade(@player, @other, offer: { fixture_tier_ids[4] => 1 }, request: { fixture_tier_ids[2] => 1 })
    friend = accounts_players(:administrator)
    Game::Friendship.create!(low_player_id: [ friend.id, @other.id ].min, high_player_id: [ friend.id, @other.id ].max)
    assert_equal [ "trade" ], kinds(Game::FeedEntries.call(nil, kind: "trade"))

    @other.update!(visibility: :friends_only)
    assert_empty Game::FeedEntries.call(nil)
    assert_equal [ [ @player, @other ] ], Game::FeedEntries.call(friend).map { |item| [ item.player, item.partner ] }

    @player.update!(visibility: :private)
    assert_empty Game::FeedEntries.call(friend)
    assert_empty Game::FeedEntries.call(nil, kind: "trade")

    @player.update!(visibility: :public)
    @other.update!(visibility: :public, banned_at: Time.current)
    assert_empty Game::FeedEntries.call(nil)
    assert_empty Game::FeedEntries.call(friend)
  end

  test "players finds a trade by either of its players" do
    conclude_trade(@player, @other, offer: { fixture_tier_ids[4] => 1 }, request: { fixture_tier_ids[2] => 1 })
    viewer = accounts_players(:administrator)

    assert_equal [ "trade" ], kinds(Game::FeedEntries.call(viewer, players: [ @other.id ]))
    assert_equal [ "trade" ], kinds(Game::FeedEntries.call(viewer, players: [ @player.id ]))
    assert_equal [ "trade" ], kinds(Game::FeedEntries.call(viewer, kind: "trade", players: [ @other.id ]))
    assert_empty Game::FeedEntries.call(viewer, players: [ viewer.id ])
  end

  test "the database keeps a trade, its partner and the partner's card for trades only, one entry per trade" do
    trade = accepted_trade(@player, @other)
    row = { player_id: @player.id, card_season_id: fixture_tier_ids[3], rarity: 4, notable: true, occurred_at: Time.current }
    traded = { trade_id: trade.id, partner_id: @other.id, partner_card_season_id: fixture_tier_ids[2] }
    refused = ->(error, **columns) do
      assert_raises(error) do
        Game::FeedEntry.transaction(requires_new: true) { Game::FeedEntry.create!(**row, **columns) }
      end
    end

    refused.(ActiveRecord::CheckViolation, kind: "trade")
    refused.(ActiveRecord::CheckViolation, kind: "trade", **traded, partner_id: nil)
    refused.(ActiveRecord::CheckViolation, kind: "repost", **traded)
    assert Game::FeedEntry.create!(**row, kind: "trade", **traded)
    refused.(ActiveRecord::RecordNotUnique, kind: "trade", **traded)
  end

  # Set entries

  def set_entries = Game::FeedEntry.where(kind: "set").order(:id)

  def set_values(entry) = entry.values_at(:player_id, :set_id, :tier, :set_count, :notable, :card_season_id, :rarity, :pack_id, :trade_id)

  test "an opening that reaches tiers of several sets is one set entry: the highest result, the count of sets, at the opening's time" do
    *, metroidvania = insert_four_themes

    pack = open_pack(@player, [ fixture_tier_ids[0] ] * 5)

    entry = set_entries.sole
    assert_equal [ @player.id, metroidvania, "gold", 4, true, nil, nil, nil, nil ], set_values(entry)
    assert_equal pack.opened_at, entry.occurred_at
    assert_equal [ "set" ], Game::FeedEntries.call(nil).reject(&:filler).map { it.entry.kind }
  end

  test "bronze and silver of one set in one opening are one result, silver" do
    common, uncommon, = fixture_tier_ids
    theme = insert_set([ common, uncommon, fixture_tier_ids[2] ], { bronze: 1, silver: 1, gold: 2, complete: 3 })

    open_pack(@player, [ common ] * 5)

    assert_equal [ [ @player.id, theme, "silver", 1, true, nil, nil, nil, nil ] ], set_entries.map { set_values(it) }
  end

  test "gold and complete reached together are the completion" do
    common = fixture_tier_ids[0]
    franchise = insert_set([ common ], { bronze: 1, silver: 1, gold: 1, complete: 1 }, kind: "franchise", key: "dark-souls",
      params: { "franchise" => "Dark Souls" })

    open_pack(@player, [ common ] * 5)

    assert_equal [ [ franchise, "complete", 1 ] ], set_entries.pluck(:set_id, :tier, :set_count)
  end

  test "two sets at the same tier: the lowest set id is the highest result" do
    common = fixture_tier_ids[0]
    rare = fixture_tier_ids[2]
    first = insert_set([ common, rare ], { bronze: 1, complete: 2 }, key: "roguelike")
    insert_set([ common, rare ], { bronze: 1, complete: 2 }, key: "horror")

    open_pack(@player, [ common ] * 5)

    assert_equal [ [ first, "bronze", 2 ] ], set_entries.pluck(:set_id, :tier, :set_count)
  end

  test "across sets the highest result stands for the larger share of its set: Dark Souls expert at 4 of 10 over Roguelike adept at 16 of 62" do
    common = fixture_tier_ids[0]
    season = catalog_seasons(:one)
    seed_card_seasons(Array.new(70) { 0.1 + (it * 0.001) }, season:)
    extra = Catalog::CardSeason.where(season_id: season.id, rarity: nil).order(:id).ids
    Catalog::CardSeason.where(id: extra).update_all(rarity: 1)
    insert_set([ common, *extra.first(61) ], Catalog::TierTable.tiers(62), key: "roguelike")
    dark_souls = insert_set([ common, *extra.last(9) ], Catalog::TierTable.tiers(10), kind: "franchise", key: "dark-souls",
      params: { "franchise" => "Dark Souls" })
    hold_all(@player, extra.first(15) + extra.last(3))

    open_pack(@player, [ common ] * 5)

    assert_equal [ [ dark_souls, "expert", 2 ] ], set_entries.pluck(:set_id, :tier, :set_count)
  end

  test "an opening that reaches no tier writes no set entry" do
    open_pack(@player, [ fixture_tier_ids[4] ] * 5)

    assert_empty set_entries
  end

  test "each opening that reaches tiers is its own set entry" do
    common, uncommon, = fixture_tier_ids
    theme = insert_set([ common, uncommon ], { bronze: 1, complete: 2 })
    open_pack(@player, [ common ] * 5)

    open_pack(@player, [ uncommon ] * 5)

    assert_equal [ [ theme, "bronze" ], [ theme, "complete" ] ], set_entries.pluck(:set_id, :tier)
  end

  test "a tier event handled again adds no row, changes nothing and publishes nothing" do
    insert_four_themes
    open_pack(@player, [ fixture_tier_ids[0] ] * 5)
    events = game_events(@player).select { it.is_a?(Game::SetTierReached) || it.is_a?(Game::SetCompleted) }
    assert_equal 6, events.size

    assert_no_changes -> { [ set_entries.map(&:attributes), game_events(@player).size ] } do
      events.each { Game::Handlers::SetTierFeed.call(it) }
    end
  end

  test "an accepted trade that crosses tiers for both players is one set entry per player, with that player's results" do
    common, uncommon, rare, = fixture_tier_ids
    roguelike = insert_set([ common, rare ], { bronze: 1, complete: 2 }, key: "roguelike")
    horror = insert_set([ uncommon, rare ], { bronze: 1, silver: 1, complete: 2 }, key: "horror")

    conclude_trade(@player, @other, offer: { common => 1 }, request: { uncommon => 1 })

    assert_equal({ @player.id => [ horror, "silver", 1 ], @other.id => [ roguelike, "bronze", 1 ] },
      set_entries.pluck(:player_id, :set_id, :tier, :set_count).to_h { |player_id, *result| [ player_id, result ] })
    assert_equal [ nil ], set_entries.pluck(:trade_id).uniq
  end

  test "a private player's set entry is stored but hidden from a visitor" do
    insert_four_themes
    @player.update!(visibility: :private)

    open_pack(@player, [ fixture_tier_ids[0] ] * 5)

    assert_equal 1, set_entries.count
    assert_empty Game::FeedEntries.call(nil)
    assert_empty Game::FeedEntries.call(nil, kind: LiveStream::TICKER_KINDS)
  end

  test "the database keeps a set, its tier and count for set entries only, with no card, one per player and time" do
    at = Time.current
    set = { kind: "set", player_id: @player.id, set_id: catalog_sets(:valve_one).id, tier: "gold", set_count: 1, notable: true, occurred_at: at }
    refused = ->(error, **columns) do
      assert_raises(error) { Game::FeedEntry.transaction(requires_new: true) { Game::FeedEntry.create!(**set, **columns) } }
    end

    refused.(ActiveRecord::CheckViolation, set_id: nil)
    refused.(ActiveRecord::CheckViolation, tier: "platinum")
    refused.(ActiveRecord::CheckViolation, set_count: 0)
    refused.(ActiveRecord::CheckViolation, card_season_id: fixture_tier_ids[3], rarity: 4)
    refused.(ActiveRecord::CheckViolation, rarity: 4)
    refused.(ActiveRecord::CheckViolation, kind: "repost")
    refused.(ActiveRecord::CheckViolation, kind: "repost", set_id: nil, tier: nil, set_count: nil, rarity: 4)
    refused.(ActiveRecord::CheckViolation, kind: "repost", set_id: nil, tier: nil, set_count: nil, card_season_id: fixture_tier_ids[3])
    assert Game::FeedEntry.create!(**set)
    refused.(ActiveRecord::RecordNotUnique, tier: "bronze")
  end
end
