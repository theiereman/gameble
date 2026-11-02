require "test_helper"
require_relative "../../support/feed_reactions"
require_relative "../../support/game_trades"

class Game::ReactToFeedEntryTest < ActiveSupport::TestCase
  include FeedReactions
  include GameTrades

  setup do
    @author = accounts_players(:player)
    @reader = accounts_players(:moderator)
    @entry = feed_entry_of(@author)
  end

  def reactions = Game::FeedReaction.where(feed_entry_id: @entry.id)

  def events = Rails.configuration.event_store.read.of_type(Game::FeedEntryReacted).to_a

  test "a player reacts, and the entry is returned" do
    result = react(@reader, @entry, "heart")

    assert result.success?
    assert_equal @entry, result.value!
    assert_equal [ [ @reader.id, "heart" ] ], reactions.pluck(:player_id, :kind)
  end

  test "a second reaction changes the first: one per player and entry" do
    react(@reader, @entry, "heart")
    react(@reader, @entry, "wow")

    assert_equal [ "wow" ], reactions.pluck(:kind)
  end

  test "the same reaction twice leaves one row" do
    2.times { react(@reader, @entry, "gg") }

    assert_equal 1, reactions.count
  end

  test "no kind removes the reaction, removing nothing is no failure" do
    react(@reader, @entry, "thumb")

    assert react(@reader, @entry, nil).success?
    assert react(@reader, @entry, nil).success?
    assert_empty reactions
  end

  test "each of the five kinds is accepted" do
    Game::FeedReaction::KINDS.each { assert react(@reader, @entry, it).success?, it }
  end

  test "a kind outside the five fails" do
    assert_equal :unknown_reaction, react(@reader, @entry, "angry").failure
    assert_equal :unknown_reaction, react(@reader, @entry, "").failure
    assert_empty reactions
  end

  test "one event is published per call, with identifiers only" do
    assert_difference -> { events.size }, 1 do
      react(@reader, @entry, "heart")
    end
    assert_equal({ player_id: @reader.id, feed_entry_id: @entry.id, kind: "heart" }, events.last.data.symbolize_keys)
  end

  test "a failure publishes nothing and writes nothing" do
    assert_no_difference -> { events.size } do
      react(@reader, @entry, "angry")
      react(@reader, @entry.dup.tap { it.token = SecureRandom.uuid }, "heart")
    end
    assert_equal 0, Game::FeedReaction.count
  end

  test "a visitor or a banned player may not react" do
    assert_equal :player_required, Game::ReactToFeedEntry.new.call(player: nil, entry_token: @entry.token, kind: "heart").failure
    assert_equal :player_required, react(accounts_players(:banned), @entry, "heart").failure
  end

  test "a token that names no entry fails" do
    assert_equal :entry_not_found, Game::ReactToFeedEntry.new.call(player: @reader, entry_token: SecureRandom.uuid, kind: "heart").failure
    assert_equal :entry_not_found, Game::ReactToFeedEntry.new.call(player: @reader, entry_token: "nope", kind: "heart").failure
  end

  test "an entry of a banned player takes no reaction" do
    @author.update!(banned_at: Time.current)

    assert_equal :entry_not_found, react(@reader, @entry, "heart").failure
  end

  test "an entry of a private player takes no reaction from another, its author may" do
    @author.update!(visibility: "private")

    assert_equal :entry_not_found, react(@reader, @entry, "heart").failure
    assert react(@author, @entry, "heart").success?
  end

  test "an entry of a friends-only player takes a friend's reaction only" do
    @author.update!(visibility: "friends_only")
    assert_equal :entry_not_found, react(@reader, @entry, "heart").failure

    Game::Friendship.create!(low_player_id: [ @author.id, @reader.id ].min, high_player_id: [ @author.id, @reader.id ].max)

    assert react(@reader, @entry, "heart").success?
  end

  test "a trade entry takes no reaction when its partner is hidden" do
    partner = accounts_players(:administrator)
    conclude_trade(@author, partner, offer: { catalog_card_seasons(:portal_one).id => 1 }, request: { catalog_card_seasons(:rare_card_one).id => 1 })
    entry = Game::FeedEntry.find_by!(kind: "trade")
    partner.update!(visibility: "private")

    assert_equal :entry_not_found, react(@reader, entry, "heart").failure
  end

  test "a staff member sees no more than any player here" do
    @author.update!(visibility: "private")

    assert_equal :entry_not_found, react(accounts_players(:administrator), @entry, "heart").failure
  end
end
