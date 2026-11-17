require "application_system_test_case"
require_relative "../support/steam_sign_in"
require_relative "../support/live_duels"

# Two friends at phone width, each in their own browser, play the duel screen: the caller picks a card, a stat and a
# direction and calls once the guard has passed; the other sees the card face up with the call hidden, answers, and both
# see the round revealed before the live board returns. The ten rounds then end on the result, and its rematch opens the
# challenge sheet. Neither ever sees a card of the other's hand, and the answerer never sees the locked call.
class DuelPlayTest < ApplicationSystemTestCase
  include ActiveJob::TestHelper
  include SteamSignIn
  include LiveDuels

  PHONE = [ 390, 844 ].freeze
  SESSIONS = { challenger: :lea, opponent: :hugo }.freeze

  setup do
    @lea = accounts_players(:player)
    @hugo = accounts_players(:moderator)
    @lea.update!(persona_name: "Léa")
    @hugo.update!(persona_name: "Hugo")
    befriend(@lea, @hugo)
    complete_deck(@lea, "Lea")
    complete_deck(@hugo, "Hugo")
    Game::DeckCard.order(:id).pluck(:card_season_id).each_with_index { |id, index| set_percentiles(id, release: 5 + (index * 3), popularity: 90 - (index * 2)) }
    @duel = start_duel(@lea, @hugo)
    Game::Duel.where(id: @duel.id).update_all(first_caller: "challenger")
    @quake = rules_of(Game::Duel.find(@duel.id)).hand(:challenger).first
    Catalog::CardText.where(card_id: card_of(@quake.card_season_id)).update_all(title: "Quake")
  end

  teardown do
    SESSIONS.each_value { |name| using_session(name) { resize_to(*SCREEN_SIZE) } }
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

  def open_duel_pages
    { lea: @lea, hugo: @hugo }.each do |name, player|
      using_session(name) do
        resize_to(*PHONE)
        sign_in player
        visit duel_path(locale: :en, token: @duel.token)
        assert_selector "#duel-board[data-move-number='1']"
        listening
      end
    end
  end

  def focused(id) = eventually("#{id} has the focus") { page.evaluate_script("document.activeElement.id") == id }

  # The first round's reveal holds the outcome from the seat's own side and the focus, and hides the live board; it
  # stays three seconds, so the check follows the board's arrival at once.
  def reveal_shown(role)
    round = rules_of(Game::Duel.find(@duel.id)).played_rounds.first
    expected = round.winner.nil? ? "drawn" : (round.winner == role ? "won" : "lost")
    assert_selector "#duel-reveal-heading", text: /\ARound 1 #{expected}: /
    focused "duel-reveal-heading"
    assert_no_selector "#duel-live"
  end

  def press_when_armed(form)
    find("##{form} button[data-armed][aria-disabled=false]").click
  end

  test "Léa calls Quake on release, Hugo answers, both see the round revealed and the live board returns" do
    open_duel_pages

    using_session(:lea) do
      find("#duel-call label[data-card]", text: "Quake").click
      find("#duel-call [data-duel-card]:not([hidden]) label", text: /\ARelease/).click
      find("#duel-call [data-duel-stat='release']:not([hidden]) label", text: "Oldest").click
      assert_selector "#duel-call button[aria-disabled=false]"

      3.times { find("body").send_keys(:escape) }
      assert_no_selector "#duel-call input:checked", visible: :all
      assert_selector "#duel-call button[aria-disabled=true]"
      assert_selector "#duel-call"

      find("#duel-call label[data-card]", text: "Quake").click
      find("#duel-call [data-duel-card]:not([hidden]) label", text: /\ARelease/).click
      find("#duel-call [data-duel-stat='release']:not([hidden]) label", text: "Oldest").click
      press_when_armed("duel-call")
      assert_selector "#duel-board[data-move-number='2']"
      assert_selector "#duel-current-call h2", text: /oldest/i
    end
    deliver

    using_session(:hugo) do
      assert_selector "#duel-board[data-move-number='2']"
      assert_selector "#duel-current-call .card__title", text: /quake/i
      assert_selector "#duel-current-call h2", text: /hidden call/i
      assert_selector "#duel-status", text: "Léa has called. Their card: Quake.", visible: :all
      within("#duel-board") { assert_no_text(/oldest/i) }
      assert_no_selector "#duel-hand", text: "Quake"
      find("#duel-answer label[data-card]", match: :first).click
      press_when_armed("duel-answer")
      assert_selector "#duel-board[data-move-number='3']"
      reveal_shown(:opponent)
    end
    deliver
    using_session(:lea) { reveal_shown(:challenger) }
    scores = rules_of(Game::Duel.find(@duel.id)).scores

    using_session(:lea) do
      click_on "Next"
      assert_selector "#duel-live"
      assert_no_selector "#duel-reveal"
      assert_selector ".duel-board__figure", text: "#{scores[:challenger]} – #{scores[:opponent]}"
      focused "duel-round-heading"
    end
    using_session(:hugo) do
      assert_selector "#duel-live"
      assert_selector ".duel-board__figure", text: "#{scores[:opponent]} – #{scores[:challenger]}"
    end

    play_round(@duel)
    deliver
    using_session(:lea) do
      assert_selector "#duel-board[data-move-number='5']"
      assert_selector "#duel-live"
      find("#duel-call label[data-card]", match: :first).click
      assert_selector "#duel-call [data-duel-card]:not([hidden]) .duel-option--called", text: "Already called"
      assert_selector "#duel-call [data-duel-card]:not([hidden]) input[value=release][aria-disabled=true]", visible: :all
    end
  end

  test "the ten rounds end on the result, whose rematch opens the challenge sheet waiting for the friend" do
    open_duel_pages

    10.times { play_round(@duel) }
    deliver

    rules = rules_of(Game::Duel.find(@duel.id))
    SESSIONS.each do |role, name|
      other = Game::DuelRules.other(role)
      line = { draw: "Draw with", role => "Win against", other => "Loss against" }.fetch(rules.result)
      using_session(name) do
        assert_selector "#duel-result-heading", text: /#{line} #{role == :challenger ? "Hugo" : "Léa"}, #{rules.scores[role]} to #{rules.scores[other]}/
        focused "duel-result-heading"
        assert_selector "ol.duel-rounds > li", count: 10
        assert_no_selector "#duel-hand"
        assert_no_selector ".tab-bar"
        assert_no_selector ".top-bar__bridge"
      end
    end

    using_session(:lea) do
      find("button[aria-label='Rematch Hugo']").click
      assert_selector "#duel-seated", text: "Waiting for Hugo's answer…"
    end
  end
end
