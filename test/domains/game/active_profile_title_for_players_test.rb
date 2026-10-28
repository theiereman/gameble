require "test_helper"
require_relative "../../support/active_titles"

class Game::ActiveProfileTitleForPlayersTest < ActiveSupport::TestCase
  include ActiveTitles

  setup do
    @wearer = accounts_players(:player)
    @bare = accounts_players(:moderator)
    @lapsed = accounts_players(:administrator)
  end

  def titles_of(*players) = Game::ActiveProfileTitle.for_players(players)

  test "maps each player who wears an earned title to it, and omits the others" do
    earn_title(@wearer)
    earn_title(@bare, equip: false)

    titles = titles_of(@wearer, @bare, @lapsed)

    assert_equal [ @wearer.id ], titles.keys
    assert_equal %w[adept studio valve], titles.fetch(@wearer.id).then { [ it.rank, it.kind, it.key ] }
  end

  test "a title the player no longer earns shows nothing" do
    earn_title(@wearer)
    Game::SetTier.where(player_id: @wearer.id).delete_all

    assert_empty titles_of(@wearer)
    assert_nil Game::ActiveProfileTitle.call(@wearer)
  end

  test "agrees with the single-player read" do
    earn_title(@wearer)

    assert_equal Game::ActiveProfileTitle.call(@wearer), titles_of(@wearer, @bare).fetch(@wearer.id)
  end

  test "reads a fixed number of queries whatever the number of players" do
    earn_title(@wearer)
    earn_title(@lapsed)
    queries = []
    count = ->(*, payload) { queries << payload[:sql] unless payload[:name] == "SCHEMA" }

    ActiveSupport::Notifications.subscribed(count, "sql.active_record") { titles_of(@wearer, @bare, @lapsed) }

    assert_equal 2, queries.size
  end

  test "an empty list reads nothing" do
    assert_empty titles_of
  end
end
