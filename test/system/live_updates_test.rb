require "application_system_test_case"

class LiveUpdatesTest < ApplicationSystemTestCase
  include ActiveJob::TestHelper

  setup do
    @hugo = accounts_players(:player)
    @lea = accounts_players(:moderator)
    @max = accounts_players(:administrator)
    @hugo.update!(persona_name: "Hugo")
    @lea.update!(persona_name: "Lea")
    @max.update!(persona_name: "Max")
    @portal = catalog_card_seasons(:portal_one).id
    @depths = catalog_card_seasons(:rare_card_one).id
    OmniAuth.config.test_mode = true
  end

  teardown do
    OmniAuth.config.mock_auth.delete(:steam)
    OmniAuth.config.test_mode = false
  end

  def befriend(first, second)
    low, high = [ first.id, second.id ].minmax
    Game::Friendship.create!(low_player_id: low, high_player_id: high)
  end

  def sign_in(player)
    OmniAuth.config.mock_auth[:steam] = OmniAuth::AuthHash.new(provider: "steam", uid: "https://steamcommunity.com/openid/id/#{player.steam_id}")
    visit home_path(locale: :en)
    click_steam_sign_in
    assert_signed_in
  end

  def listening
    assert_selector "turbo-cable-stream-source[connected]", visible: :all
    page.execute_script("window.liveMark = true")
  end

  def not_reloaded? = page.evaluate_script("window.liveMark === true")

  def deliver = perform_enqueued_jobs(only: PlayerStreamJob)

  test "a proposal and a counter reach the other player without a reload and move the badge" do
    befriend(@hugo, @lea)
    Game::Holding.create!(player_id: @hugo.id, card_season_id: @portal, quantity: 4, reserved: 0)
    Game::Holding.create!(player_id: @lea.id, card_season_id: @depths, quantity: 2, reserved: 0)

    sign_in @hugo
    assert_selector ".hub-menu a.menu-item .menu-item__badge--zero", text: "0"
    listening
    using_session("lea") do
      sign_in @lea
      visit trades_path(locale: :en)
      assert_selector ".trades"
      listening
    end

    trade = Game::ProposeTrade.new.call(player: @lea, recipient: @hugo, offer: { @depths => 1 }, request: { @portal => 2 }).value!
    deliver

    assert_selector ".hub-menu a.menu-item .menu-item__badge--alert", text: "1"
    assert_selector ".hub-menu a.menu-item .visually-hidden", text: "1 trade waiting for you", visible: :all
    assert not_reloaded?
    using_session("lea") do
      assert_selector ".trade-row", text: /HUGO/i
      assert_selector ".trade-board .trade-chip", text: /WAITING/i
      assert not_reloaded?
    end

    Game::CounterTrade.new.call(player: @hugo, trade_id: trade.id, offer: { @portal => 1 }, request: { @depths => 1 }).value!
    deliver

    assert_selector ".hub-menu a.menu-item .menu-item__badge--zero", text: "0"
    assert not_reloaded?
    using_session("lea") do
      assert_selector ".trade-board .trade-chip", text: /YOUR TURN/i
      within(".trade-board") { assert_button "Accept" }
      assert not_reloaded?
    end
  end

  test "an invitation reaches the Friends screen, and its acceptance tells the sender NOUVEL AMI" do
    sign_in @hugo
    visit friends_path(locale: :en)
    listening

    Game::SendInvitation.new.call(player: @max, code: "7K2Q-F3NX").value!
    deliver
    assert_selector ".friends__invitation", text: "Max invites you"
    assert not_reloaded?

    Game::SendInvitation.new.call(player: @hugo, code: "8F2D-K9XM").value!
    invitation = Game::Invitation.pending.find_by!(sender_id: @hugo.id)
    Game::AcceptInvitation.new.call(player: @lea, token: invitation.token).value!
    deliver

    assert_selector ".toast", text: "Lea is now one of your friends."
    assert_selector ".friends__friend", text: "Lea"
    assert not_reloaded?
  end

  test "the Friends screen holds its refresh while a code is typed" do
    sign_in @hugo
    visit friends_path(locale: :en)
    listening
    page.execute_script("addEventListener('gameble:friends-updated', () => { document.body.dataset.signal = 'seen' })")
    fill_in "Add with a code", with: "8F2D"

    Game::SendInvitation.new.call(player: @max, code: "7K2Q-F3NX").value!
    deliver
    assert_selector "body[data-signal=seen]"
    assert_no_selector ".friends__invitation", text: "Max invites you"
    assert_field "Add with a code", with: "8F2D"

    fill_in "Add with a code", with: ""
    assert_selector ".friends__invitation", text: "Max invites you"
  end

  test "a partner's update during an in-place counter-proposal keeps the picks, and the board catches up once it ends" do
    [ @lea, @max ].each { befriend(@hugo, it) }
    Game::Holding.create!(player_id: @hugo.id, card_season_id: @portal, quantity: 4, reserved: 0)
    Game::Holding.create!(player_id: @lea.id, card_season_id: @depths, quantity: 2, reserved: 0)
    Game::Holding.create!(player_id: @max.id, card_season_id: @depths, quantity: 1, reserved: 0)
    trade = Game::ProposeTrade.new.call(player: @lea, recipient: @hugo, offer: { @depths => 1 }, request: { @portal => 2 }).value!
    deliver

    sign_in @hugo
    visit trade_path(token: trade.token, locale: :en)
    listening
    page.execute_script("addEventListener('gameble:trades-updated', () => { document.body.dataset.signals = (Number(document.body.dataset.signals || 0) + 1).toString() })")
    within(".trade-board") { click_on "Counter" }
    within(".trade-side--own") do
      find(".stepper__button--more").click
      assert_selector ".stepper[aria-valuenow='3']"
    end

    Game::ProposeTrade.new.call(player: @max, recipient: @hugo, offer: { @depths => 1 }, request: { @portal => 1 }).value!
    deliver
    assert_selector "body[data-signals='1']"
    Game::CancelTrade.new.call(player: @lea, trade_id: trade.id).value!
    deliver
    assert_selector "body[data-signals='2']"

    assert_selector ".trade-side--editing", count: 2
    within(".trade-side--own") { assert_selector ".stepper[aria-valuenow='3']" }
    assert_no_selector ".trade-row", text: /MAX/i
    assert not_reloaded?

    click_on "Discard the changes"
    within("#trade-undo-dialog") { click_on "Discard the changes" }

    assert_selector ".trade-board .trade-chip--muted", text: /CLOSED/i
    assert_selector ".trade-row", text: /MAX/i
    assert_no_selector ".trade-side--editing"
    assert not_reloaded?
  end

  test "the swap after an acceptance plays out before the accepter's own update refreshes the board" do
    befriend(@hugo, @lea)
    Game::Holding.create!(player_id: @hugo.id, card_season_id: @portal, quantity: 4, reserved: 0)
    Game::Holding.create!(player_id: @lea.id, card_season_id: @depths, quantity: 2, reserved: 0)
    trade = Game::ProposeTrade.new.call(player: @lea, recipient: @hugo, offer: { @depths => 1 }, request: { @portal => 2 }).value!
    deliver

    sign_in @hugo
    visit trade_path(token: trade.token, locale: :en)
    listening
    page.execute_script(<<~JS)
      window.renders = []
      window.flights = 0
      const animate = Element.prototype.animate
      Element.prototype.animate = function (frames, options) {
        if (JSON.stringify(frames).includes("translate(")) window.flights += 1
        return animate.call(this, frames, options)
      }
      document.addEventListener("turbo:before-render", () => {
        window.renders.push(document.querySelector(".trade-board--swapping") ? "during the swap" : "outside the swap")
      })
      document.addEventListener("turbo:load", () => {
        if (!document.querySelector(".trade-board[data-live-refresh-hold]")) return
        window.signalDuringSwap = true
        dispatchEvent(new CustomEvent("gameble:trades-updated"))
      }, { once: true })
    JS

    within(".trade-board") { click_on "Accept" }

    assert_selector ".trade-board .trade-chip--lime", text: /DONE/i
    assert_selector ".trade-board__message:focus", text: "Trade done."
    deliver
    assert page.evaluate_script("window.signalDuringSwap === true"), "the update arrived while the cards were flying"
    assert_equal 2, page.evaluate_script("window.flights")
    assert_selector ".trade-board:not([data-live-refresh-hold])"
    wait_until_renders(2)
    assert_equal [ "outside the swap" ], page.evaluate_script("window.renders").uniq
    within(".trade-side--own") { assert_selector ".trade-card__new", text: /NEW/i }
    assert not_reloaded?
  end

  def wait_until_renders(count)
    Timeout.timeout(Capybara.default_max_wait_time) do
      sleep 0.05 until page.evaluate_script("window.renders.length") >= count
    end
  end
end
