require "test_helper"
require_relative "../../support/game_packs"

# The activity feed (CAP-13, AD-10, AD-11, AD-13; stories 6.1, 6.2): the
# handler's choice of entries and the read that filters them by kind and
# through Game::Visibility.
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

  # Feed rows of `kind` written straight, newest last, on a pack of `player`
  # (only pulls have a handler yet).
  def add_entries(player, count, kind: "pull", notable: true, from: 1.hour.ago)
    pack = create_pack(player)
    rows = Array.new(count) do |position|
      at = from + position.seconds
      { kind:, player_id: player.id, pack_id: pack.id, card_season_id: fixture_tier_ids[3], position:,
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
    create_pack(@player, cards: [ fixture_tier_ids[3] ] * 5)
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

    assert_equal [ "trade" ], Game::FeedEntries.call(nil, kind: "trade").map { |item| item.entry.kind }
    assert_equal [ "pull" ], Game::FeedEntries.call(nil, kind: "pull").map { |item| item.entry.kind }
    assert_equal %w[pull trade], Game::FeedEntries.call(nil).map { |item| item.entry.kind }.uniq.sort
    assert_empty Game::FeedEntries.call(nil, kind: "repost")
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
end
