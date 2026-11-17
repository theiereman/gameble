require "test_helper"
require_relative "../../support/live_duels"

class Game::NoteDuelPresenceTest < ActiveSupport::TestCase
  include LiveDuels

  setup do
    @now = Time.utc(2026, 11, 17, 12, 0)
    @lea = accounts_players(:player)
    @hugo = accounts_players(:moderator)
    befriend(@lea, @hugo)
    complete_deck(@lea, "Lea")
    complete_deck(@hugo, "Hugo")
    @duel = start_duel(@lea, @hugo)
    @seat = Game::DuelSeat.find_by!(duel_id: @duel.id, role: "challenger")
  end

  def note(at: @now) = Game::NoteDuelPresence.new.call(stream_key: @seat.stream_key, at:).value!

  test "the lease runs 20 seconds ahead, writes nothing but the seat and publishes nothing" do
    events = Rails.configuration.event_store.read.count
    other = Game::DuelSeat.find_by!(duel_id: @duel.id, role: "opponent").attributes
    duel = Game::Duel.find(@duel.id).attributes

    presence = note

    assert_equal @duel.id, presence.duel_id
    assert_equal @now + 20.seconds, @seat.reload.present_until
    assert_equal events, Rails.configuration.event_store.read.count
    assert_equal other, Game::DuelSeat.find_by!(duel_id: @duel.id, role: "opponent").attributes
    assert_equal duel, Game::Duel.find(@duel.id).attributes
  end

  test "it says whether the lease had lapsed: the first one, a lapsed one, not a held one" do
    assert note.lapsed
    assert_not note(at: @now + 10.seconds).lapsed
    assert_not note(at: @now + 25.seconds).lapsed
    assert note(at: @now + 60.seconds).lapsed
  end

  test "a seat that has left, an unknown key or no key leaves everything alone" do
    @seat.update!(status: "left")

    assert_equal [ @duel.id, false ], note.to_h.values
    assert_nil @seat.reload.present_until
    assert_nil Game::NoteDuelPresence.new.call(stream_key: "unknown", at: @now).value!
    assert_nil Game::NoteDuelPresence.new.call(stream_key: nil, at: @now).value!
  end
end
