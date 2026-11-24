require "application_system_test_case"
require_relative "../support/steam_sign_in"
require_relative "../support/live_duels"

# Two friends in desktop windows: the Duels screen puts the challenge block in a 400px column beside the decks, and
# the challenge opens as a centred dialog. The duel then fills the window, the player's deck on the left and the opponent's on the right, the table
# and the call between them, the chosen card opening in place.
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
    sign_in_browser(player.steam_id)
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
        column[:width] == 360 && decks[:left] >= column[:right] && (decks[:top] - column[:top]).abs < 2
      end

      click_on "Challenge a friend"
      within("#duel-sheet") do
        choose "Lea deck"
        choose "Hugo"
      end
      eventually("the dialog is centred in the window") do
        dialog = box("#duel-sheet")
        window = page.evaluate_script("({ width: document.documentElement.clientWidth, height: document.documentElement.clientHeight })")
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
      eventually("the player's deck is left of the opponent's, each a single list") do
        theirs = box("#duel-their-deck")
        mine = box("#duel-my-deck")
        mine[:right] <= theirs[:left] && box("#duel-my-deck .duel-deck__card:nth-child(3)")[:top] > box("#duel-my-deck .duel-deck__card:nth-child(2)")[:top]
      end
      assert_selector "#duel-their-deck .duel-deck__name", text: "Hugo card A"

      find("#duel-my-deck [data-card] .duel-deck__body", match: :first).click
      assert_selector "#duel-my-deck [data-card]:has(input:checked)"
      assert_selector "#duel-my-deck .duel-deck__card:not([data-card])", visible: :all
      eventually("the chosen card stands in the call slot of the table, the button under both slots inside it") do
        slot = box("#duel-table .duel-table__slot--call .duel-face")
        button = box("#duel-call button[type=submit]")
        slot[:height] > 0 && slot[:bottom] <= button[:top] && button[:bottom] <= box("#duel-table")[:bottom]
      end
      find("#duel-my-deck [data-duel-pick]:not([aria-disabled=true])", match: :first).click
      press_when_armed("duel-call")
      assert_selector "#duel-board[data-move-number='2']"
    end
    deliver

    using_session(:hugo) do
      visit duel_path(locale: :en, token: duel.token)
      assert_selector "#duel-board[data-move-number='2']"
      find("#duel-my-deck [data-card] .duel-deck__body", match: :first).click
      press_when_armed("duel-answer")
      assert_selector "#duel-reveal-heading"
      eventually("the reveal plays inside the table, the decks staying in view") { box("#duel-reveal")[:left] >= box("#duel-table")[:left] && box("#duel-my-deck")[:height] > 0 }
    end
  end
end
