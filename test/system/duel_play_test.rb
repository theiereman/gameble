require "application_system_test_case"
require_relative "../support/steam_sign_in"
require_relative "../support/live_duels"

# Two friends play a whole duel, each in their own browser: the challenge reaches the friend's Duels screen, the
# acceptance the challenger's, and every move the other's board by push, while the mover's own page keeps the board
# its move already shows. Neither ever sees a card of the other's hand, and the answerer never sees the locked call.
# The challenger calls high and the friend low, so a call's words never appear on the answerer's board before the
# round is revealed.
class DuelPlayTest < ApplicationSystemTestCase
  include ActiveJob::TestHelper
  include SteamSignIn
  include LiveDuels

  SESSIONS = { challenger: :lea, opponent: :hugo }.freeze

  setup do
    @lea = accounts_players(:player)
    @hugo = accounts_players(:moderator)
    @lea.update!(persona_name: "Léa")
    @hugo.update!(persona_name: "Hugo")
    befriend(@lea, @hugo)
    complete_deck(@lea, "Lea")
    complete_deck(@hugo, "Hugo")
  end

  def sign_in(player)
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

  def board_at(move_number) = assert_selector("#duel-board[data-move-number='#{move_number}']")

  def prefix(role) = role == :challenger ? "Lea" : "Hugo"

  def hands_kept_apart
    SESSIONS.each do |role, name|
      using_session(name) { assert_no_selector "#duel-hand", text: "#{prefix(Game::DuelRules.other(role))} card" }
    end
  end

  def call_next(round)
    rules = rules_of(Game::Duel.sole)
    caller = rules.caller
    words = I18n.t("duel_stats.directions.#{rules.stats_left(caller).first}.#{caller == :challenger ? "high" : "low"}", locale: :en)

    using_session(SESSIONS[caller]) do
      within("form#duel-call") do
        first("input[name=card]").click
        choose words
        click_on "Call"
      end
      board_at(2 * round)
      assert_selector "#duel-current-call h2", text: /#{Regexp.escape(words)}/i
      listening
      page.execute_script("document.getElementById('duel-board').dataset.kept = ''")
    end
    deliver
    [ rules, words ]
  end

  def answer_next(round, rules, words)
    using_session(SESSIONS[rules.answerer]) do
      board_at(2 * round)
      assert_selector "#duel-current-call h2", text: /hidden call/i
      within("#duel-board") { assert_no_text(/#{Regexp.escape(words)}/i) }
      within("form#duel-answer") do
        first("input[name=card]").click
        click_on "Answer with this card"
      end
      board_at((2 * round) + 1)
      listening
    end
    deliver
    using_session(SESSIONS[rules.caller]) { board_at((2 * round) + 1) }
  end

  test "Léa challenges Hugo, he accepts, and both play the ten rounds in turn to the same result" do
    using_session(:hugo) do
      sign_in @hugo
      visit duels_path(locale: :en)
      listening
    end
    using_session(:lea) do
      sign_in @lea
      visit duels_path(locale: :en)
      within("form#duel-challenge") do
        choose "Lea deck"
        choose "Hugo"
        click_on "Challenge"
      end
      assert_selector "#duel-seated", text: "Waiting for Hugo's answer…"
      listening
    end
    deliver

    using_session(:hugo) do
      within("#duel-received") do
        assert_text "Léa challenges you to a duel."
        choose "Hugo deck"
        click_on "Accept"
      end
      board_at(1)
      listening
    end
    deliver

    using_session(:lea) do
      within("#duel-seated") do
        assert_text "Duel in progress against Hugo."
        click_on "Resume"
      end
      board_at(1)
      listening
    end
    hands_kept_apart

    (1..10).each do |round|
      rules, words = call_next(round)
      using_session(SESSIONS[rules.answerer]) { board_at(2 * round) }
      using_session(SESSIONS[rules.caller]) { assert_selector "#duel-board[data-move-number='#{2 * round}'][data-kept]" }
      hands_kept_apart
      answer_next(round, rules, words)
      hands_kept_apart
    end

    rules = rules_of(Game::Duel.sole)
    assert rules.finished?
    SESSIONS.each do |role, name|
      other = Game::DuelRules.other(role)
      line = { draw: "Draw with", role => "Win against", other => "Loss against" }.fetch(rules.result)
      using_session(name) do
        board_at(21)
        assert_selector ".duel-board__result",
          text: "#{line} #{role == :challenger ? "Hugo" : "Léa"} · #{rules.scores[role]} – #{rules.scores[other]}"
        assert_selector ".duel-rounds li", count: 10
        assert_no_selector "#duel-hand"
      end
    end
  end
end
