require "application_system_test_case"
require_relative "../support/steam_sign_in"
require_relative "../support/live_duels"

# Léa wins her first duel of the day against Hugo and reads CAPSULE DE DUEL GAGNÉE, follows it to the capsule screen and
# opens a three-card capsule in the duel canister from the special reserve; she wins again and reads that the capsule was
# won today. Hugo, who lost, reads no capsule line.
class DuelCapsuleSystemTest < ApplicationSystemTestCase
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
    Game::DeckCard.where(deck_id: Game::Deck.where(player_id: @lea.id).select(:id)).pluck(:card_season_id)
      .each { set_percentiles(it, **Game::DuelStat::STATS.index_with { 100 }) }
    Game::MarkAllocationSeen.new.call(player: @lea).value!
    @duel = start_duel(@lea, @hugo)
    %i[lea hugo].each do |name|
      using_session(name) { page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", features: [ { name: "prefers-reduced-motion", value: "reduce" } ]) }
    end
  end

  teardown do
    %i[lea hugo].each { |name| using_session(name) { resize_to(*SCREEN_SIZE) } }
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

  def open_duel_page(name, player)
    using_session(name) do
      resize_to(*PHONE)
      sign_in player
      visit duel_path(locale: :en, token: @duel.token)
      assert_selector "#duel-board[data-move-number='1']"
      listening
    end
  end

  test "the first win of the day gives a capsule that opens in the duel canister, the second gives none and says so" do
    open_duel_page(:lea, @lea)
    open_duel_page(:hugo, @hugo)

    10.times { play_round(@duel) }
    deliver

    using_session(:hugo) do
      assert_selector "#duel-result-heading", text: /Loss against Léa/
      assert_no_text "DUEL CAPSULE WON"
      assert_no_selector "#duel-capsule-line *"
    end
    using_session(:lea) do
      assert_selector "#duel-result-heading", text: /Win against Hugo/
      find("#duel-capsule-line a", text: "DUEL CAPSULE WON").click
      assert_current_path booster_path(locale: :en)
      assert_selector "[role=tab][data-reserve=special][aria-selected=true]", text: "SPECIAL · 1"
      assert_selector ".booster__origin", text: "DUEL CAPSULE"
      assert_selector ".booster__canister-facts", text: "3 cards"
      find(".booster-canister").click

      assert_selector ".booster-card[data-dealt]", count: 3, wait: 10
      eventually("the duel capsule should be opened") { Game::Pack.find_by!(player_id: @lea.id, kind: "duel").opened? }
    end

    @duel = start_duel(@lea, @hugo)
    10.times { play_round(@duel) }
    using_session(:lea) do
      visit duel_path(locale: :en, token: @duel.token)
      assert_selector "#duel-result-heading", text: /Win against Hugo/
      assert_selector "#duel-capsule-line", text: "Duel capsule already won today."
      assert_no_selector "#duel-capsule-line a"
    end
    assert_equal 1, Game::Pack.where(player_id: @lea.id, kind: "duel").count
  end
end
