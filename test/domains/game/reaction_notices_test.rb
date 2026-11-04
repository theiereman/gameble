require "test_helper"
require_relative "../../support/feed_reactions"
require_relative "../../support/game_trades"

# The first reaction of each player to someone else's feed entry, recorded once and kept when withdrawn,
# and the owners told only when a new player reacts.
class Game::ReactionNoticesTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  include FeedReactions
  include GameTrades

  setup do
    @ana = accounts_players(:player)
    @lea = accounts_players(:moderator)
    @max = accounts_players(:administrator)
    @entry = feed_entry_of(@ana)
  end

  def notices(entry = @entry) = Game::ReactionNotice.where(feed_entry_id: entry.id).order(:id).pluck(:reactor_id)

  def told = enqueued_jobs.select { it[:job] == PlayerStreamJob }.flat_map { ActiveJob::Arguments.deserialize(it[:args]).first }

  def reactions_for(*players) = players.map { { player_id: it.id, topic: "reactions" } }

  test "a first reaction records its reactor and tells the entry's owner once it commits" do
    assert react(@lea, @entry, "heart").success?

    assert_equal [ @lea.id ], notices
    assert_equal reactions_for(@ana), told
  end

  test "withdrawing and giving the reaction again, twenty times, records nothing more and tells no one" do
    react(@lea, @entry, "heart")
    clear_enqueued_jobs

    20.times do
      react(@lea, @entry, nil)
      react(@lea, @entry, "heart")
    end

    assert_equal [ @lea.id ], notices
    assert_empty told
  end

  test "changing the kind records nothing more and tells no one" do
    react(@lea, @entry, "heart")
    clear_enqueued_jobs

    react(@lea, @entry, "wow")

    assert_equal [ @lea.id ], notices
    assert_empty told
  end

  test "every kind tells the owner, the middle finger too" do
    react(@lea, @entry, "middle_finger")

    assert_equal reactions_for(@ana), told
  end

  test "a second player's first reaction is recorded and tells the owner again" do
    react(@lea, @entry, "heart")
    clear_enqueued_jobs

    react(@max, @entry, "gg")

    assert_equal [ @lea.id, @max.id ], notices
    assert_equal reactions_for(@ana), told
  end

  test "a reaction to one's own entry is not recorded and tells no one" do
    react(@ana, @entry, "heart")

    assert_empty notices
    assert_empty told
  end

  test "a reaction to a trade entry tells both of its players; theirs to it tells no one" do
    conclude_trade(@ana, @max, offer: { catalog_card_seasons(:portal_one).id => 1 }, request: { catalog_card_seasons(:rare_card_one).id => 1 })
    entry = Game::FeedEntry.find_by!(kind: "trade")
    clear_enqueued_jobs

    react(@max, entry, "heart")
    assert_empty notices(entry)
    assert_empty told

    react(@lea, entry, "wow")
    assert_equal [ @lea.id ], notices(entry)
    assert_equal reactions_for(@ana, @max).sort_by { it[:player_id] }, told.sort_by { it[:player_id] }
  end

  test "a released player's notices go with them; others' stay" do
    react(@lea, @entry, "heart")
    react(@max, @entry, "gg")

    Game::ReleasePlayer.new.call(player: @lea).value!

    assert_not Game::ReactionNotice.exists?(reactor_id: @lea.id)
    assert_equal [ @max.id ], notices
  end

  test "an entry removed takes its notices with it" do
    react(@lea, @entry, "heart")

    Game::FeedEntry.where(id: @entry.id).delete_all

    assert_empty Game::ReactionNotice.all
  end
end
