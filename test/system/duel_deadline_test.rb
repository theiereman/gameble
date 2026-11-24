require "application_system_test_case"
require_relative "../support/steam_sign_in"
require_relative "../support/live_duels"

class DuelDeadlineTest < ApplicationSystemTestCase
  include ActiveJob::TestHelper
  include SteamSignIn
  include LiveDuels

  setup do
    @lea = accounts_players(:player)
    @hugo = accounts_players(:moderator)
    @lea.update!(persona_name: "Léa")
    @hugo.update!(persona_name: "Hugo")
    befriend(@lea, @hugo)
    complete_deck(@lea, "Lea")
    complete_deck(@hugo, "Hugo")
  end

  teardown { travel_back }

  def sign_in(player)
    sign_in_browser(player.steam_id)
  end

  def listening
    assert_selector "turbo-cable-stream-source[connected]", visible: :all
    assert_no_selector "turbo-cable-stream-source:not([connected])", visible: :all
  end

  def deliver = perform_enqueued_jobs(only: [ PlayerStreamJob, DuelStreamJob ])

  def run_out(seconds)
    travel seconds
    Game::SweepDuelDeadlinesJob.perform_now
    deliver
  end

  test "a challenge nobody accepts lapses for both friends" do
    duel = Game::ChallengeFriend.new.call(player: @lea, friend: @hugo, deck_token: deck_token_of(@lea)).value!
    using_session(:hugo) do
      sign_in @hugo
      visit duels_path(locale: :en)
      assert_selector "#duel-dialog .duel-clock", text: "You"
      listening
    end
    using_session(:lea) do
      sign_in @lea
      visit duels_path(locale: :en)
      assert_selector "#duel-seated .duel-clock", text: "Hugo"
      listening
    end

    run_out(61.seconds)

    using_session(:hugo) { assert_no_selector "#duel-dialog" }
    using_session(:lea) { assert_no_selector "#duel-seated" }
    assert_equal "lapsed", Game::Duel.find(duel.id).state
  end

  test "a call then an answer left to run out are played by the server and shown on both boards" do
    duel = start_duel(@lea, @hugo)
    { lea: @lea, hugo: @hugo }.each do |name, player|
      using_session(name) do
        sign_in player
        visit duel_path(token: duel.token, locale: :en)
        assert_selector "#duel-board[data-move-number='1'] .duel-clock"
        listening
      end
    end

    run_out(61.seconds)
    { lea: 2, hugo: 2 }.each { |name, move| using_session(name) { assert_selector "#duel-board[data-move-number='#{move}']" } }

    run_out(46.seconds)

    %i[lea hugo].each do |name|
      using_session(name) do
        assert_selector "#duel-board[data-move-number='3']"
        assert_text "Move played automatically"
      end
    end
    assert Game::DuelRound.sole.then { it.caller_automatic && it.answer_automatic }
  end
end
