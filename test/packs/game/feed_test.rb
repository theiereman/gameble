require "test_helper"
require_relative "../../support/game_packs"

class Game::FeedTest < ActiveSupport::TestCase
  include GamePacks

  setup do
    @player = accounts_players(:player)
    @other = accounts_players(:moderator)
  end

  def open_pack(player, cards)
    cards += [ fixture_tier_ids[0] ] * 4 if cards.size == 1
    create_pack(player, cards:)
    Game::OpenPack.new.call(player:).value!
  end

  def entries = Game::FeedEntry.order(:id).pluck(:position, :notable, :rarity)

  # Feed rows of `kind` written straight, newest last: pulls and discoveries
  # on a pack of `player`, trades and reposts with none.
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
    assert_equal [ pack.id ], Game::FeedEntry.pluck(:pack_id).uniq
    assert_equal [ @player.id ], Game::FeedEntry.pluck(:player_id).uniq
  end

  test "a pack with no notable pull leaves its best card as a filler" do
    common, uncommon, rare, = fixture_tier_ids

    open_pack(@player, [ common, rare, uncommon, rare, common ])

    assert_equal [ [ 1, false, 3 ] ], entries
  end

  test "the same event handled twice adds nothing and never fails" do
    open_pack(@player, [ fixture_tier_ids[3] ] * 5)
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
    epic = fixture_tier_ids[3]
    travel_to(2.hours.ago) { open_pack(@player, [ epic ]) }
    travel_to(1.hour.ago) { open_pack(@other, [ epic ]) }

    shown = Game::FeedEntries.call(nil)

    assert_equal [ @other, @player ], shown.map(&:player)
    assert shown.none?(&:filler)
  end

  test "an entry of a private, friends only or banned player is hidden from a visitor" do
    epic = fixture_tier_ids[3]
    open_pack(@player, [ epic ])
    open_pack(@other, [ epic ])

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
    epic = fixture_tier_ids[3]
    open_pack(@player, [ epic ])
    open_pack(@other, [ epic ])
    @player.update!(visibility: :private)

    assert_equal [ @other ], Game::FeedEntries.call(accounts_players(:administrator)).map(&:player)

    @player.update!(visibility: :public, banned_at: Time.current)
    assert_equal [ @other ], Game::FeedEntries.call(accounts_players(:administrator)).map(&:player)
  end

  test "lower rarities stay out while the feed holds enough, and fill it when it is quiet" do
    common = fixture_tier_ids[0]
    epic = fixture_tier_ids[3]
    travel_to(3.hours.ago) { open_pack(@player, [ common ] * 5) }
    open_pack(@other, [ epic ])

    quiet = Game::FeedEntries.call(nil)
    assert_equal [ true, false ], quiet.map(&:filler).sort_by { |filler| filler ? 0 : 1 }
    assert_equal [ @other, @player ], quiet.map(&:player)

    Game::FeedEntries::MIN.times { open_pack(@other, [ epic ]) }
    assert Game::FeedEntries.call(nil).none?(&:filler)
  end

  test "an empty feed is empty" do
    assert_empty Game::FeedEntries.call(nil)
  end

  test "an opening writes pulls" do
    open_pack(@player, [ fixture_tier_ids[3] ])

    assert_equal [ "pull" ], Game::FeedEntry.distinct.pluck(:kind)
  end

  test "a kind shows only its entries, the whole feed shows every kind" do
    open_pack(@player, [ fixture_tier_ids[3] ])
    add_entries(@other, 1, kind: "trade")
    add_entries(@other, 2, kind: "repost")

    assert_equal [ "trade" ], Game::FeedEntries.call(nil, kind: "trade").map { |item| item.entry.kind }
    assert_equal [ "pull" ], Game::FeedEntries.call(nil, kind: "pull").map { |item| item.entry.kind }
    assert_equal %w[repost repost], Game::FeedEntries.call(nil, kind: "repost").map { |item| item.entry.kind }
    assert_equal %w[pull repost trade], Game::FeedEntries.call(nil).map { |item| item.entry.kind }.uniq.sort
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
    add_entries(@other, 1, kind: "trade")
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
end
