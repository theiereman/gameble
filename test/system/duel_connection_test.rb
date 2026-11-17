require "application_system_test_case"
require_relative "../support/steam_sign_in"
require_relative "../support/live_duels"

# A duel survives a dropped connection or a reload: a friend whose connection is lost is shown to the other with the
# time left to return, both resume at the same round when they do; a move sent while offline reads ENVOI… and lands
# once when the connection returns; a duel left for the hub is led back to from the DUELS badge, the bell and Duels.
class DuelConnectionTest < ApplicationSystemTestCase
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
    @duel = start_duel(@lea, @hugo)
    Game::Duel.where(id: @duel.id).update_all(first_caller: "challenger")
    @duel = play_round(play_round(Game::Duel.find(@duel.id)))
  end

  teardown do
    SESSIONS.each_value do |name|
      using_session(name) do
        resize_to(*SCREEN_SIZE)
        network(false)
        refuse_moves(false)
      end
    end
  end

  # A request the last test left in flight sends the session cookie back after the reset: a reused session starts clean.
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
        assert_selector "#duel-board[data-move-number='5']"
        listening
      end
    end
  end

  def network(offline)
    page.driver.browser.execute_cdp("Network.emulateNetworkConditions", offline:, latency: 0, downloadThroughput: -1, uploadThroughput: -1)
  end

  def refuse_moves(refused)
    blocked = [ "*://*.example.test/*", *(%w[*/calls */answers] if refused) ]
    browser = page.driver.browser
    browser.execute_cdp("Network.enable")
    browser.execute_cdp("Network.setBlockedURLs", urls: blocked)
  end

  def drop_connection(player)
    network(true)
    ActionCable.server.remote_connections.where(current_player: player).disconnect
    assert_selector ".duel-connection__line--own:not([hidden])", text: /\AConnection lost… \d+ s/
  end

  def lease_lapsed(player)
    Game::DuelSeat.where(duel_id: @duel.id, player_id: player.id).update_all(present_until: 5.seconds.ago)
  end

  def reconnect
    network(false)
    page.execute_script("document.dispatchEvent(new Event('visibilitychange'))")
    assert_selector ".duel-connection__line--own[hidden]", visible: :all, wait: 20
    listening
  end

  test "Hugo's page loses its connection in round 3: Léa sees it with its countdown, and both resume at round 3 when he returns" do
    open_duel_pages

    using_session(:hugo) { drop_connection(@hugo) }
    lease_lapsed(@hugo)
    DuelAbsenceJob.perform_now
    deliver

    using_session(:lea) do
      assert_selector "#duel-connection .duel-clock", text: /\AHugo's connection lost… \d+ s/
      assert_selector "#duel-connection", text: "Hugo's connection is lost.", visible: :all
      assert_selector "#duel-board[data-move-number='5']"
      assert_selector "#duel-round-heading", text: /Round 3 \/ 10/i
    end

    using_session(:hugo) { reconnect }
    eventually("the return is pushed") { enqueued_jobs.any? { it["job_class"] == "DuelStreamJob" } }
    deliver

    using_session(:lea) do
      assert_no_selector "#duel-connection .duel-clock"
      assert_selector "#duel-board[data-move-number='5']"
    end
    using_session(:hugo) { assert_selector "#duel-board[data-move-number='5']" }
    assert_not_nil Game::DuelSeat.find_by!(duel_id: @duel.id, player_id: @hugo.id).present_until
  end

  test "a move sent while the connection is down reads ENVOI… and lands once when it returns" do
    open_duel_pages
    call_round(Game::Duel.find(@duel.id))
    deliver

    using_session(:hugo) do
      assert_selector "#duel-board[data-move-number='6']"
      find("#duel-answer label[data-card]", match: :first).click
      refuse_moves(true)
      find("#duel-answer button[data-armed][aria-disabled=false]").click
      assert_selector "#duel-answer button", text: /sending…/i
      assert_selector "#duel-answer button[aria-disabled=true]"

      refuse_moves(false)
      assert_selector "#duel-board[data-move-number='7']", wait: 15
    end
    assert_equal 3, Game::DuelRound.where(duel_id: @duel.id).where.not(answer_card_season_id: nil).count
    assert_equal 7, Game::Duel.find(@duel.id).move_number
  end

  test "Hugo leaves the duel for the hub: the DUELS badge, the bell and Duels lead him back" do
    open_duel_pages

    using_session(:hugo) do
      visit home_path(locale: :en)
      assert_selector "#tab-duels-badge .tab-bar__badge", text: "1"
      assert_selector "#tab-duels-badge .visually-hidden", text: ", 1 duel in progress", visible: :all
      assert_selector "#menu-duels-badge .menu-item__badge", text: "1", visible: :all

      find(".bell__button").click
      assert_selector "#bell-panel:popover-open"
      within("#bell-panel") do
        assert_selector ".bell__sentence", text: "Your duel against Léa awaits your return."
        assert_selector ".bell__action", text: /resume/i
      end
      find("#bell-panel .bell__link", text: "Your duel against Léa").click
      assert_selector "#duel-board[data-move-number='5']"

      visit duels_path(locale: :en)
      assert_selector "#duel-seated", text: "Duel in progress against Léa."
      find("#duel-seated a[aria-label='Resume the duel against Léa']").click
      assert_selector "#duel-board[data-move-number='5']"
    end
  end

  test "the same duel reloads where it stands" do
    open_duel_pages

    using_session(:hugo) do
      visit current_path
      assert_selector "#duel-board[data-move-number='5']"
      listening
      assert_no_selector ".duel-connection__line:not([hidden])"
    end
  end
end
