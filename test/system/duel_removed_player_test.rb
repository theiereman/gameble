require "application_system_test_case"
require_relative "../support/steam_sign_in"
require_relative "../support/live_duels"

# An administrator bans Hugo during round 4: Léa's duel goes on, Hugo's moves played by the game, to a result that
# reads anonymous.
class DuelRemovedPlayerTest < ApplicationSystemTestCase
  include ActiveJob::TestHelper
  include SteamSignIn
  include LiveDuels

  PHONE = [ 390, 844 ].freeze

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
    @duel = play_round(play_round(play_round(Game::Duel.find(@duel.id))))
  end

  teardown do
    travel_back
    %i[lea hugo].each { |name| using_session(name) { resize_to(*SCREEN_SIZE) } }
  end

  def sign_in(player)
    page.driver.browser.execute_cdp("Network.clearBrowserCookies")
    mock_steam_sign_in(player.steam_id)
    visit home_path(locale: :en)
    click_steam_sign_in
    assert_signed_in
  end

  def listening
    assert_selector "turbo-cable-stream-source[connected]", visible: :all
    assert_no_selector "turbo-cable-stream-source:not([connected])", visible: :all
  end

  def deliver = perform_enqueued_jobs(only: [ PlayerStreamJob, DuelStreamJob ])

  def open_duel_pages
    { lea: @lea, hugo: @hugo }.each do |name, player|
      using_session(name) do
        resize_to(*PHONE)
        sign_in player
        visit duel_path(locale: :en, token: @duel.token)
        assert_selector "#duel-board[data-move-number='7']"
        listening
      end
    end
  end

  # Léa plays her moves as the rules would; when Hugo is to move, his time runs out and the sweep plays for him.
  def play_out
    40.times do
      duel = Game::Duel.find(@duel.id)
      return if duel.state == "finished"

      rules = rules_of(duel)
      if (rules.pending ? rules.answerer : rules.caller) == :challenger
        rules.pending ? answer_round(duel) : call_round(duel)
      else
        travel 61.seconds
        Game::SweepDuelDeadlinesJob.perform_now
      end
      deliver
    end
  end

  test "an administrator bans Hugo during round 4: Léa's duel goes on with his moves played automatically to a result that reads anonymous" do
    open_duel_pages

    Accounts::BanPlayer.new.call(staff: accounts_players(:administrator), player: @hugo, reason: "Cheating").value!
    using_session(:lea) do
      assert_selector "#duel-board[data-move-number='7']"
      assert_selector "#duel-round-heading", text: /Round 4 \/ 10/i
    end

    travel 61.seconds
    Game::SweepDuelDeadlinesJob.perform_now
    deliver
    using_session(:lea) do
      assert_selector "#duel-board[data-move-number='8']"
      assert_text "An anonymous player has called"
      assert_selector ".duel-board__opponent", text: "An anonymous player"
    end

    play_out

    using_session(:lea) do
      assert_selector "#duel-result-heading", text: /against An anonymous player|with An anonymous player/i
    end
    finished = Game::Duel.find(@duel.id)
    assert_equal "finished", finished.state
    assert_equal 10, Game::DuelRound.where(duel_id: finished.id).count
    assert Game::DuelRound.find_by!(duel_id: finished.id, number: 4).caller_automatic
  end
end
