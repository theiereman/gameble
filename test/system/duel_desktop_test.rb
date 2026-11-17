require "application_system_test_case"
require_relative "../support/steam_sign_in"
require_relative "../support/live_duels"

# Two friends in desktop windows: the Duels screen puts the challenge block in a 400px column beside the decks, and
# the challenge opens as a centred dialog. The duel then fills the window, the opponent's deck on the left and the
# player's on the right, the choices in the centre and the hand at the foot, the chosen card raised 12px.
class DuelDesktopTest < ApplicationSystemTestCase
  include ActiveJob::TestHelper
  include SteamSignIn
  include LiveDuels

  DESKTOP = [ 1280, 900 ].freeze
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

  teardown do
    SESSIONS.each_value { |name| using_session(name) { resize_to(*SCREEN_SIZE) } }
  end

  def sign_in(player)
    mock_steam_sign_in(player.steam_id)
    visit home_path(locale: :en)
    click_steam_sign_in
    assert_signed_in
  end

  def deliver = perform_enqueued_jobs(only: [ PlayerStreamJob, DuelStreamJob ])

  def box(selector)
    page.evaluate_script(<<~JS).transform_keys(&:to_sym)
      (() => {
        const element = document.querySelector(#{selector.to_json})
        const { left, right, top, bottom, width, height } = element.getBoundingClientRect()
        return { left, right, top, bottom, width, height }
      })()
    JS
  end

  def press_when_armed(form) = find("##{form} button[data-armed][aria-disabled=false]").click

  test "Léa challenges Hugo from the centred dialog and the two play a round in the desktop layout" do
    using_session(:hugo) do
      resize_to(*DESKTOP)
      sign_in @hugo
      visit duels_path(locale: :en)
      assert_selector "turbo-cable-stream-source[connected]", visible: :all
    end

    using_session(:lea) do
      resize_to(*DESKTOP)
      sign_in @lea
      visit duels_path(locale: :en)
      assert_selector "turbo-cable-stream-source[connected]", visible: :all

      eventually("the challenge column sits beside the decks") do
        column = box(".duel-lobby")
        decks = box(".duel-decks")
        column[:width] == 400 && decks[:left] >= column[:right] && (decks[:top] - column[:top]).abs < 2
      end

      click_on "Challenge a friend"
      within("#duel-sheet") do
        choose "Lea deck"
        choose "Hugo"
      end
      eventually("the dialog is centred in the window") do
        dialog = box("#duel-sheet")
        window = page.evaluate_script("({ width: innerWidth, height: innerHeight })")
        (dialog[:left] + dialog[:width] / 2 - window["width"] / 2.0).abs < 2 && (dialog[:top] + dialog[:height] / 2 - window["height"] / 2.0).abs < 2
      end
      within("#duel-sheet") do
        click_on "Challenge"
        assert_text "Waiting for Hugo's answer…"
      end
    end
    deliver

    using_session(:hugo) do
      within("#duel-dialog") do
        choose "Hugo deck"
        click_on "Accept"
      end
      assert_selector "#duel-board[data-move-number='1']"
    end
    deliver

    duel = Game::Duel.order(:id).last
    Game::Duel.where(id: duel.id).update_all(first_caller: "challenger")
    using_session(:lea) do
      visit duel_path(locale: :en, token: duel.token)
      assert_selector "#duel-board[data-move-number='1']"
      assert_selector "turbo-cable-stream-source[connected]", visible: :all
      eventually("the opponent's deck is left of the player's, each a 3 × 4 grid of 74px cells") do
        theirs = box("#duel-their-deck")
        mine = box("#duel-my-deck")
        theirs[:right] <= mine[:left] && box("#duel-their-deck .duel-deck__card")[:height] == 74 && box("#duel-my-deck li:nth-child(4)")[:top] > box("#duel-my-deck li:nth-child(3)")[:top]
      end
      assert_selector "#duel-their-deck .duel-deck__name", text: "Hugo card A"

      find("#duel-call label[data-card]", match: :first).click
      eventually("the chosen card is raised 12px") do
        raised = box("#duel-call label[data-card]:has(input:checked) .card")[:top]
        resting = box("#duel-call label[data-card]:not(:has(input:checked)) .card")[:top]
        resting - raised == 12
      end
      find("#duel-call [data-duel-card]:not([hidden]) label", match: :first).click
      eventually("the stats and the directions sit side by side") do
        stats = box("#duel-call [data-duel-group=stat]")
        directions = box("#duel-call [data-duel-group=direction]")
        stats[:right] <= directions[:left] && (stats[:top] - directions[:top]).abs < 2 && box("#duel-call button")[:top] > stats[:bottom] && box("#duel-hand .duel-group--hand")[:top] > box("#duel-call button")[:bottom]
      end
      find("#duel-call [data-duel-stat]:not([hidden]) label", match: :first).click
      press_when_armed("duel-call")
      assert_selector "#duel-board[data-move-number='2']"
    end
    deliver

    using_session(:hugo) do
      visit duel_path(locale: :en, token: duel.token)
      assert_selector "#duel-board[data-move-number='2']"
      find("#duel-answer label[data-card]", match: :first).click
      press_when_armed("duel-answer")
      assert_selector "#duel-reveal-heading"
      eventually("the reveal keeps the phone column") { box("#duel-reveal")[:width] <= 480 }
    end
  end
end
