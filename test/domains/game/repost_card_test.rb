require "test_helper"
require_relative "../../support/game_packs"
require_relative "../../support/holdings"

# Reposting a card the player holds: the operation's checks, the feed entry
# its handler writes, and how the feed shows it.
class Game::RepostCardTest < ActiveSupport::TestCase
  include Holdings
  include GamePacks

  setup do
    @player = accounts_players(:player)
    @common, _, _, @epic, @legendary = fixture_tier_ids
  end

  def repost(card_season_id, player: @player)
    Game::RepostCard.new.call(player:, card_season_id:)
  end

  def reposts = Game::FeedEntry.where(kind: "repost")

  test "a held card of any rarity is reposted: one notable entry with no pack, and one event" do
    hold(@player, @common, 1)
    now = Time.utc(2026, 10, 8, 12, 0)

    result = travel_to(now) { repost(@common) }

    assert result.success?
    entry = reposts.sole
    assert_equal [ @player.id, @common, 1, true, nil, nil, now ],
      [ entry.player_id, entry.card_season_id, entry.rarity, entry.notable, entry.pack_id, entry.position, entry.occurred_at ]
    event = game_events(@player, Game::CardReposted).sole
    assert_equal({ player_id: @player.id, card_season_id: @common }, event.data)
    assert_equal result.value!, event
  end

  test "the entry carries the card's rarity" do
    hold(@player, @legendary, 2)

    repost(@legendary).value!

    assert_equal 5, reposts.sole.rarity
  end

  test "the eleventh repost within an hour is refused, and the next one passes once the hour is over" do
    hold(@player, @epic, 1)
    start = Time.utc(2026, 10, 8, 12, 0)

    travel_to(start) do
      Game::RepostCard::HOURLY_LIMIT.times do
        Game::FeedEntry.create!(kind: "repost", player_id: @player.id, card_season_id: @common, rarity: 1, notable: true,
          occurred_at: start - 10.minutes)
      end

      assert_no_difference -> { reposts.count + game_events(@player, Game::CardReposted).size } do
        assert_equal :repost_limit_reached, repost(@epic).failure
      end
    end

    travel_to(start + 61.minutes) { assert repost(@epic).success? }
  end

  test "a second repost of a card within 24 hours is refused; another card and another player pass" do
    hold(@player, @epic, 1)
    hold(@player, @common, 1)
    other = accounts_players(:moderator)
    Game::Holding.create!(player_id: other.id, card_season_id: @epic, quantity: 1)
    start = Time.utc(2026, 10, 8, 12, 0)

    travel_to(start) { repost(@epic).value! }

    travel_to(start + 23.hours) do
      assert_no_difference -> { reposts.count + game_events(@player, Game::CardReposted).size } do
        assert_equal :already_reposted, repost(@epic).failure
      end
      assert repost(@common).success?
      assert repost(@epic, player: other).success?
    end
    travel_to(start + 25.hours) { assert repost(@epic).success? }
  end

  test "a card not held is refused and writes nothing" do
    hold(@player, @epic, 0)

    assert_no_difference -> { Game::FeedEntry.count + Rails.configuration.event_store.read.count } do
      assert_equal :card_not_owned, repost(@epic).failure
      assert_equal :card_not_owned, repost(@legendary).failure
      assert_equal :card_not_owned, repost(nil).failure
    end
  end

  test "another player's copies do not count" do
    Game::Holding.create!(player_id: accounts_players(:moderator).id, card_season_id: @epic, quantity: 2)

    assert_equal :card_not_owned, repost(@epic).failure
  end

  test "copies all promised to a trade still count as held" do
    hold(@player, @epic, 2, reserved: 2)

    assert repost(@epic).success?
    assert_equal 1, reposts.count
  end

  test "a visitor, a banned or a deleted player is refused" do
    hold(@player, @epic, 1)

    assert_no_difference -> { Game::FeedEntry.count } do
      assert_equal :player_required, repost(@epic, player: nil).failure
      assert_equal :player_required, repost(@epic, player: accounts_players(:banned)).failure
      @player.update!(deleted_at: Time.current, steam_id: nil)
      assert_equal :player_required, repost(@epic, player: @player).failure
    end
  end

  test "the handler publishes nothing more" do
    hold(@player, @epic, 1)

    assert_difference -> { Rails.configuration.event_store.read.count }, 1 do
      repost(@epic).value!
    end
  end

  test "the feed shows the repost under the whole feed and its filter, never as a filler" do
    hold(@player, @common, 1)
    repost(@common).value!

    [ nil, "repost" ].each do |kind|
      shown = Game::FeedEntries.call(nil, kind:)
      assert_equal [ [ "repost", @player, false ] ], shown.map { [ it.entry.kind, it.player, it.filler ] }
    end
    assert_empty Game::FeedEntries.call(nil, kind: "pull")
  end

  test "the repost stays once the card is traded away" do
    holding = hold(@player, @epic, 1)
    repost(@epic).value!

    holding.update!(quantity: 0)

    assert_equal [ "repost" ], Game::FeedEntries.call(nil).map { it.entry.kind }
  end

  test "a private, friends only or banned player's repost is hidden from others" do
    hold(@player, @epic, 1)
    repost(@epic).value!
    stranger = accounts_players(:moderator)

    @player.update!(visibility: :private)
    assert_empty Game::FeedEntries.call(nil)
    assert_empty Game::FeedEntries.call(stranger, kind: "repost")

    @player.update!(visibility: :friends_only)
    assert_empty Game::FeedEntries.call(stranger)

    @player.update!(visibility: :public, banned_at: Time.current)
    assert_empty Game::FeedEntries.call(nil)
  end

  test "the database keeps a pack and a position for pulls and discoveries only" do
    pack = create_pack(@player)
    row = { player_id: @player.id, card_season_id: @epic, rarity: 4, notable: true, occurred_at: Time.current }
    refused = ->(**columns) do
      assert_raises(ActiveRecord::CheckViolation) do
        Game::FeedEntry.transaction(requires_new: true) { Game::FeedEntry.create!(**row, **columns) }
      end
    end

    refused.(kind: "repost", pack_id: pack.id, position: 0)
    refused.(kind: "pull")
    refused.(kind: "discovery", pack_id: pack.id)
    assert Game::FeedEntry.create!(**row, kind: "repost")
    assert Game::FeedEntry.create!(**row, kind: "pull", pack_id: pack.id, position: 0)
  end
end
