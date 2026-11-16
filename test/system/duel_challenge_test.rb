require "application_system_test_case"
require_relative "../support/steam_sign_in"
require_relative "../support/live_duels"

# Léa challenges Hugo from the sheet; Hugo answers from a dialog on whatever page he is on. Her sheet waits with a
# countdown and cancels, hears a refusal and lands on the duel an acceptance opens. A player holding drafts only
# cannot send a challenge and is told why.
class DuelChallengeTest < ApplicationSystemTestCase
  include ActiveJob::TestHelper
  include SteamSignIn
  include LiveDuels

  setup do
    @lea = accounts_players(:player)
    @hugo = accounts_players(:moderator)
    @lea.update!(persona_name: "Léa")
    @hugo.update!(persona_name: "Hugo")
    befriend(@lea, @hugo)
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

  def challenge_hugo
    click_on "Challenge a friend"
    within("#duel-sheet") do
      choose "Lea deck"
      choose "Hugo"
      click_on "Challenge"
      assert_text "Waiting for Hugo's answer…"
    end
    deliver
  end

  test "Léa cancels, Hugo refuses, then Hugo accepts and both land on the duel" do
    complete_deck(@lea, "Lea")
    complete_deck(@hugo, "Hugo")
    using_session(:hugo) do
      sign_in @hugo
      visit duels_path(locale: :en)
      listening
    end
    using_session(:lea) do
      sign_in @lea
      visit duels_path(locale: :en)
      listening
      challenge_hugo
      assert_selector "#duel-sheet .duel-clock"
    end
    using_session(:hugo) do
      within("#duel-dialog") { assert_text "Léa challenges you to a duel." }
    end

    using_session(:lea) do
      within("#duel-sheet") { click_on "Cancel" }
      deliver
    end
    using_session(:hugo) do
      assert_no_selector "#duel-dialog"
      assert_text "Léa cancelled their challenge."
    end

    using_session(:lea) do
      visit duels_path(locale: :en)
      listening
      challenge_hugo
    end
    using_session(:hugo) do
      within("#duel-dialog") { click_on "Refuse" }
      assert_text "Challenge refused."
      deliver
    end
    using_session(:lea) do
      within("#duel-sheet") { assert_text "Hugo declined." }
    end

    using_session(:lea) do
      visit duels_path(locale: :en)
      listening
      challenge_hugo
    end
    using_session(:hugo) do
      within("#duel-dialog") do
        choose "Hugo deck"
        click_on "Accept"
      end
      assert_selector "#duel-board"
    end
    deliver
    using_session(:lea) { assert_selector "#duel-board" }
  end

  test "a player holding drafts only sees the challenge disabled with its reason" do
    Game::CreateDeck.new.call(player: @lea, name: "Brouillon").value!
    sign_in @lea
    visit duels_path(locale: :en)

    click_on "Challenge a friend"

    within("#duel-sheet") do
      assert_selector "button[type=submit][aria-disabled=true]", text: "CHALLENGE"
      assert_text "You need a complete 12-card deck to challenge."
      assert_text "A draft cannot play: it needs 12 cards."
    end
  end
end
