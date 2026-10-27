require "test_helper"
require_relative "../../support/game_packs"

# Game::NextPackSize (story 8.12): the card count of the pack the next
# opening opens, as Game::OpenPack picks it.
class Game::NextPackSizeTest < ActiveSupport::TestCase
  include GamePacks

  setup { @player = accounts_players(:player) }

  test "a regular pack first in line holds five cards" do
    create_pack(@player, available_at: 1.hour.ago)
    create_pack(@player, kind: :bonus, available_at: 1.minute.ago)

    assert_equal 5, Game::NextPackSize.call(@player)
  end

  test "a daily bonus pack first in line holds three cards" do
    create_pack(@player, kind: :bonus, available_at: 2.hours.ago)
    create_pack(@player, available_at: 1.hour.ago)

    assert_equal 3, Game::NextPackSize.call(@player)
  end

  test "nothing available: nil, packs to come and opened packs left aside" do
    create_pack(@player, kind: :bonus, available_at: 1.hour.from_now)
    create_pack(@player, available_at: 2.hours.ago, opened_at: 1.hour.ago)
    create_pack(accounts_players(:moderator), available_at: 1.hour.ago)

    assert_nil Game::NextPackSize.call(@player)
  end

  test "a pack still to come is ignored until its time" do
    now = Time.current.change(usec: 0)
    create_pack(@player, kind: :bonus, available_at: now + 10.minutes)
    create_pack(@player, available_at: now + 20.minutes)

    assert_nil Game::NextPackSize.call(@player, now:)
    assert_equal 3, Game::NextPackSize.call(@player, now: now + 15.minutes)
    assert_equal 3, Game::NextPackSize.call(@player, now: now + 30.minutes)
  end
end
