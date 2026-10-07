require "test_helper"
require_relative "../../support/game_packs"

# The activity feed (CAP-13, AD-10, AD-11, AD-13; story 6.1): the handler's
# choice of entries and the read that filters them through Game::Visibility.
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
end
