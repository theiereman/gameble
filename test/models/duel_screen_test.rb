require "test_helper"
require_relative "../support/live_duels"

# What a seat's board reads from its view: the last round shown face up for a few seconds, the stats still open to
# call, and the rematch once the duel is over.
class DuelScreenTest < ActiveSupport::TestCase
  include LiveDuels

  setup do
    @lea = accounts_players(:player)
    @hugo = accounts_players(:moderator)
    @lea.update!(persona_name: "Léa")
    @hugo.update!(persona_name: "Hugo")
    befriend(@lea, @hugo)
    complete_deck(@lea, "Lea")
    complete_deck(@hugo, "Hugo")
    @duel = start_duel(@lea, @hugo)
    Game::Duel.where(id: @duel.id).update_all(first_caller: "challenger")
  end

  def screen_of(player)
    duel = Game::DuelByToken.call(@duel.token)
    DuelScreen.new(duel, duel.seat_of(player), locale: :en)
  end

  test "no round has been revealed at the start, so there is nothing to show and nothing to rematch" do
    screen = screen_of(@lea)

    assert_nil screen.reveal
    assert_nil screen.rematch
    assert screen.stat_open?(:release)
  end

  test "the last answered round is revealed for ten seconds, from each seat's side, then no more" do
    freeze_time do
      play_round(@duel)
      lea = screen_of(@lea).reveal
      hugo = screen_of(@hugo).reveal

      assert_equal 1, lea.number
      assert lea.called
      assert_not hugo.called
      assert_equal lea.caller_card, hugo.caller_card
      assert_equal lea.mine, hugo.theirs
      assert_equal lea.answer_card, lea.theirs
      assert_not_nil lea.stat

      travel 9.seconds
      assert screen_of(@lea).reveal
      travel 2.seconds
      assert_nil screen_of(@lea).reveal
    end
  end

  test "a round is revealed only while its answer is the latest move" do
    freeze_time do
      play_round(@duel)
      assert screen_of(@lea).reveal
      call_round(@duel)
      assert_nil screen_of(@lea).reveal
    end
  end

  test "a stat called in a revealed round is no longer open to its caller, and still open to the other seat" do
    play_round(@duel)
    stat = Game::DuelRound.find_by!(duel_id: @duel.id, number: 1).stat.to_sym

    assert_not screen_of(@lea).stat_open?(stat)
    assert screen_of(@hugo).stat_open?(stat)
  end

  test "once the duel is over the rematch names the friend and the player's own deck, or why it is not possible" do
    10.times { play_round(@duel) }
    token = @hugo.token

    ready = screen_of(@lea).rematch
    assert_equal [ token, deck_token_of(@lea), nil ], [ ready.friend_token, ready.deck_token, ready.unavailable ]

    Accounts::Player.where(id: @hugo.id).update_all(reachable_until: 1.minute.ago)
    assert_equal :offline, screen_of(@lea).rematch.unavailable

    Accounts::Player.where(id: @hugo.id).update_all(reachable_until: 1.day.from_now)
    admin = accounts_players(:administrator)
    befriend(@hugo, admin)
    complete_deck(admin, "Admin")
    Game::ChallengeFriend.new.call(player: @hugo, friend: admin, deck_token: deck_token_of(@hugo)).value!
    assert_equal :in_duel, screen_of(@lea).rematch.unavailable
  end
end
