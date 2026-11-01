require "test_helper"
require_relative "../../support/custom_sets"

# The library sets the daily sync reaches: those never synced first, then
# the least recently synced, up to the day's limit, players in good
# standing only; custom sets never.
class Game::LibrarySetsDueTest < ActiveSupport::TestCase
  include CustomSets

  def due(limit: 10) = Game::LibrarySetsDue.call(limit:)

  test "never synced first, then the oldest sync, then the newest, as player and token pairs" do
    player, moderator, administrator = accounts_players(:player, :moderator, :administrator)
    recent = create_library_set(player, synced_at: 1.hour.ago)
    never = create_library_set(moderator, synced_at: nil)
    oldest = create_library_set(administrator, synced_at: 3.days.ago, library_private_since: 1.day.ago)
    create_custom_set(player)

    assert_equal [ [ moderator.id, never.token ], [ administrator.id, oldest.token ], [ player.id, recent.token ] ], due
    assert_equal [ never.token, oldest.token ], due(limit: 2).map(&:last)
  end

  test "sets never synced follow their creation" do
    first = create_library_set(accounts_players(:moderator), synced_at: nil)
    second = create_library_set(accounts_players(:player), synced_at: nil)

    assert_equal [ first.token, second.token ], due.map(&:last)
  end

  test "the sets of a banned or a deleted player are never due" do
    create_library_set(accounts_players(:banned), synced_at: nil)
    deleted = accounts_players(:moderator)
    create_library_set(deleted, synced_at: nil)
    deleted.update_columns(deleted_at: Time.current, steam_id: nil)
    kept = create_library_set(accounts_players(:player))

    assert_equal [ [ accounts_players(:player).id, kept.token ] ], due
  end
end
