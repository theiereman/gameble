require "test_helper"
require_relative "../../support/holdings"

# Game::CollectionSlots: a player's copies of the
# cards asked about, and which are new against their watermark.
class Game::CollectionSlotsTest < ActiveSupport::TestCase
  include Holdings
  Slot = Game::CollectionSlots::Slot

  setup do
    @player = accounts_players(:player)
    @portal, @common, @legendary = %i[portal_one common_card_one legendary_card_one].map { catalog_card_seasons(it).id }
    @state = Game::PlayerState.find_by!(player_id: @player.id)
  end

  def slots(ids = [ @portal, @common, @legendary ]) = Game::CollectionSlots.call(@player, ids)

  test "without a watermark every gained holding is new, one never gained is not; in one query" do
    gained = Time.zone.parse("2026-10-06 10:00:00.123456")
    hold(@player, @portal, 2, gained_at: gained)
    hold(@player, @common, 1)
    hold(@player, @legendary, 0, gained_at: gained)
    hold(accounts_players(:moderator), @legendary, 3, gained_at: gained)

    result = nil
    assert_queries_count(1) { result = slots([ @portal, @common, @legendary, @portal ]) }

    assert_equal({ @portal => Slot.new(copies: 2, new: true, gained_at: gained), @common => Slot.new(copies: 1, new: false, gained_at: nil) }, result)
    assert_equal gained.usec, result.fetch(@portal).gained_at.usec
  end

  test "a holding gained after the watermark is new; at or before it, not" do
    watermark = Time.zone.parse("2026-10-06 10:00:00.500000")
    @state.update_columns(collection_seen_up_to: watermark)
    hold(@player, @portal, 1, gained_at: watermark.change(usec: 500_001))
    hold(@player, @common, 1, gained_at: watermark)
    hold(@player, @legendary, 1, gained_at: watermark - 1)

    assert_equal({ @portal => true, @common => false, @legendary => false }, slots.transform_values(&:new))
  end

  test "a player without a state row reads as having no watermark" do
    @state.delete
    hold(@player, @portal, 1, gained_at: 1.minute.ago)

    assert slots.fetch(@portal).new
  end

  test "another player's watermark does not count" do
    Game::PlayerState.find_by!(player_id: accounts_players(:moderator).id).update_columns(collection_seen_up_to: 1.minute.from_now)
    hold(@player, @portal, 1, gained_at: 1.minute.ago)

    assert slots.fetch(@portal).new
  end

  test "no query for a visitor or no card" do
    hold(@player, @portal, 1, gained_at: 1.minute.ago)

    assert_queries_count(0) { assert_equal({}, Game::CollectionSlots.call(nil, [ @portal ])) }
    assert_queries_count(0) { assert_equal({}, Game::CollectionSlots.call(@player, [])) }
  end
end
