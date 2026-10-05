require "test_helper"
require_relative "../../support/game_packs"

# The Game queries the web layer reads: the chest's count and an opened pack
# by token.
class Game::QueriesTest < ActiveSupport::TestCase
  include GamePacks

  setup { @player = accounts_players(:player) }

  test "the bank summary counts the packs available now, of every kind, and the next regular one" do
    now = Time.current.change(usec: 0)
    create_pack(@player)
    create_pack(@player, kind: :bonus)
    create_pack(@player, kind: :reward)
    create_pack(@player, available_at: now + 2.hours)
    create_pack(@player, available_at: now + 1.hour)
    create_pack(@player, available_at: now + 30.minutes, kind: :bonus)
    create_pack(@player, available_at: now + 20.minutes, opened_at: 1.minute.ago)
    create_pack(@player, opened_at: 1.minute.ago)
    create_pack(accounts_players(:moderator), available_at: now + 10.minutes)

    assert_equal({ available: 3, reserve_full: false, next_available_at: now + 1.hour, bonus_collectable: true }, Game::BankSummary.call(@player, now:))
  end

  test "an opened pack is found by its token for its owner only" do
    opened = create_pack(@player, opened_at: 1.minute.ago)
    unopened = create_pack(@player)

    assert_equal opened, Game::OpenedPackByToken.call(@player, opened.token)
    assert_nil Game::OpenedPackByToken.call(accounts_players(:moderator), opened.token)
    assert_nil Game::OpenedPackByToken.call(nil, opened.token)
    assert_nil Game::OpenedPackByToken.call(@player, unopened.token)
    assert_nil Game::OpenedPackByToken.call(@player, "unknown")
    assert_nil Game::OpenedPackByToken.call(@player, nil)
  end
end
