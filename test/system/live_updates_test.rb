require "application_system_test_case"
require_relative "../support/game_packs"
require_relative "../support/steam_sign_in"

class LiveUpdatesTest < ApplicationSystemTestCase
  include ActiveJob::TestHelper
  include GamePacks
  include SteamSignIn

  setup do
    @hugo = accounts_players(:player)
    @lea = accounts_players(:moderator)
    @max = accounts_players(:administrator)
    @hugo.update!(persona_name: "Hugo")
    @lea.update!(persona_name: "Lea")
    @max.update!(persona_name: "Max")
    @portal = catalog_card_seasons(:portal_one).id
    @depths = catalog_card_seasons(:rare_card_one).id
  end

  def befriend(first, second)
    low, high = [ first.id, second.id ].minmax
    Game::Friendship.create!(low_player_id: low, high_player_id: high)
  end

  def sign_in(player)
    mock_steam_sign_in(player.steam_id)
    visit home_path(locale: :en)
    click_steam_sign_in
    assert_signed_in
  end

  def listening
    assert_selector "turbo-cable-stream-source[connected]", visible: :all
    page.execute_script("window.liveMark = true")
  end

  def not_reloaded? = page.evaluate_script("window.liveMark === true")

  def listening_to_all
    assert_selector "turbo-cable-stream-source[connected]", visible: :all
    assert_no_selector "turbo-cable-stream-source:not([connected])", visible: :all
    page.execute_script("window.liveMark = true")
  end

  def open_epic(player)
    create_pack(player, cards: [ @portal ] * 5)
    Game::OpenPack.new.call(player:).value!
  end

  def goal_figures
    goal = Game::CurrentGoal.call
    [ goal[:total], goal[:target] ].map { ActiveSupport::NumberHelper.number_to_delimited(it) }.join(" / ")
  end

  def ticker_states = page.evaluate_script("document.querySelector('#live-ticker .ticker__track').getAnimations().map((a) => a.playState)")

  def assert_ticker_states(expected)
    page.document.synchronize do
      raise Capybara::ExpectationNotMet, "ticker animations: #{ticker_states.inspect}" unless ticker_states == expected
    end
  end

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

    Game::CounterTrade.new.call(player: @hugo, trade_id: trade.id, revision: Game::Trade.find(trade.id).revision, offer: { @portal => 1 }, request: { @depths => 1 }).value!
    deliver

    assert_selector ".hub-menu a.menu-item .menu-item__badge--zero", text: "0"
    assert not_reloaded?
    using_session("lea") do
      assert_selector ".trade-board .trade-chip", text: /YOUR TURN/i
      within(".trade-board") { assert_button "Accept" }
      assert not_reloaded?
    end
  end

  test "a friend going private closes the open trade on the partner's board without a reload" do
    befriend(@hugo, @lea)
    Game::Holding.create!(player_id: @hugo.id, card_season_id: @portal, quantity: 4, reserved: 0)
    Game::Holding.create!(player_id: @lea.id, card_season_id: @depths, quantity: 1, reserved: 0)
    trade = Game::ProposeTrade.new.call(player: @hugo, recipient: @lea, offer: { @portal => 2 }, request: { @depths => 1 }).value!

    sign_in @lea
    visit trade_path(token: trade.token, locale: :en)
    assert_selector ".trade-board .trade-chip", text: /YOUR TURN/i
    listening

    Accounts::SetVisibility.new.call(player: @hugo, visibility: "private").value!
    deliver

    assert_selector ".trade-board .trade-chip", text: /CLOSED/i
    assert_selector ".trade-board .trades-closed", text: "Hugo's profile is private: trades are closed."
    assert_no_button "Accept"
    assert not_reloaded?
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

  test "a cancelled invitation leaves the recipient's Friends screen without a reload" do
    invitation = Game::SendInvitation.new.call(player: @max, code: "7K2Q-F3NX").value!
    sign_in @hugo
    visit friends_path(locale: :en)
    assert_selector ".friends__invitation", text: "Max invites you"
    listening

    Game::CancelInvitation.new.call(player: @max, token: invitation.token).value!
    deliver

    assert_no_selector ".friends__invitation", text: "Max invites you"
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
      const signalDuringSwap = () => {
        if (!document.querySelector(".trade-board[data-live-refresh-hold]")) return
        document.removeEventListener("turbo:load", signalDuringSwap)
        window.signalDuringSwap = true
        dispatchEvent(new CustomEvent("gameble:trades-updated"))
      }
      document.addEventListener("turbo:load", signalDuringSwap)
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

  test "a public player's opening moves the other browsers' gauge at the next tick and tops their feed, without a reload" do
    Game::SumWeeklyGoalJob.new.perform
    sign_in @max
    assert_selector "#community-goal .hub-goal__figures", text: goal_figures
    listening_to_all
    using_session("feed") do
      visit feed_path(locale: :en)
      assert_selector ".feed__empty", text: "Nothing here yet."
      listening_to_all
    end

    open_epic(@hugo)
    perform_enqueued_jobs(only: LiveFeedJob)
    Game::SumWeeklyGoalJob.new.perform
    LiveGoalJob.perform_now

    assert_equal 1, Game::CurrentGoal.call[:total]
    assert_selector "#community-goal .hub-goal__figures", text: goal_figures
    assert_selector "#live-ticker [data-ticker-target=run] > .ticker__item", text: "Hugo pulled Portal", count: 5, visible: :all
    assert not_reloaded?
    using_session("feed") do
      assert_selector "#feed-entries > li.feed__entry", count: 6
      assert_selector "#feed-entries > li:first-child .feed__sentence", text: "Hugo completes the Valve set."
      assert_no_selector ".feed__empty"
      assert not_reloaded?
    end
  end

  test "the live feed keeps its newest entries up to the feed's limit" do
    (Game::FeedEntries::LIMIT / 5).times { open_epic(@hugo) }
    perform_enqueued_jobs(only: LiveFeedJob)
    visit feed_path(locale: :en)
    assert_selector "#feed-entries > li.feed__entry", count: Game::FeedEntries::LIMIT
    listening_to_all

    create_pack(@hugo, cards: [ catalog_card_seasons(:legendary_card_one).id ] * 5)
    Game::OpenPack.new.call(player: @hugo).value!
    perform_enqueued_jobs(only: LiveFeedJob)

    assert_selector "#feed-entries > li.feed__entry:nth-child(-n+5) .feed__tag--legendary", count: 5
    assert_selector "#feed-entries > li.feed__entry", count: Game::FeedEntries::LIMIT
    assert not_reloaded?
  end

  test "the hub's ticker scrolls, joins new items at the loop boundary, pauses under the pointer and stands still under reduced motion" do
    open_epic(@hugo)
    sign_in @max

    assert_selector "#live-ticker[data-ticker-state=scrolling] [data-ticker-target=run] > .ticker__item", count: 6, visible: :all
    assert_ticker_states([ "running" ])

    in_view = page.evaluate_script(<<~JS)
      (() => {
        const run = document.querySelector("#live-ticker [data-ticker-target=run]")
        const items = Array.from(run.children)
        items.forEach((item, place) => { item.dataset.place = place })
        const width = document.querySelector("#live-ticker .ticker__window").clientWidth
        return items.filter((item) => item.getBoundingClientRect().left - run.getBoundingClientRect().left < width).length
      })()
    JS
    page.execute_script(<<~JS)
      const queue = document.getElementById("live-ticker-queue")
      const model = document.querySelector("#live-ticker [data-ticker-target=run] > .ticker__item")
      for (let arrival = 0; arrival < 10; arrival += 1) {
        const item = model.cloneNode(true)
        delete item.dataset.place
        item.dataset.arrived = arrival
        queue.append(item)
      }
    JS
    assert_selector "#live-ticker-queue > [data-arrived]", count: 10, visible: :all
    assert_no_selector "#live-ticker [data-ticker-target=run] > [data-arrived]", visible: :all
    page.execute_script(<<~JS)
      const loop = document.querySelector("#live-ticker .ticker__track").getAnimations()[0]
      loop.currentTime = loop.effect.getComputedTiming().duration - 100
    JS
    assert_selector "#live-ticker [data-ticker-target=run] > [data-arrived]", visible: :all
    assert_no_selector "#live-ticker-queue > *", visible: :all
    assert_selector "#live-ticker [data-ticker-target=run] > .ticker__item", count: 12, visible: :all
    order = page.evaluate_script(<<~JS)
      Array.from(document.querySelectorAll("#live-ticker [data-ticker-target=run] > .ticker__item"), (item) => item.dataset.place ?? `new${item.dataset.arrived}`)
    JS
    joining = [ 10, 12 - in_view ].min
    assert_equal [ *(0...in_view).map(&:to_s), *(0...joining).map { "new#{it}" }, *(in_view...6).map(&:to_s) ].first(12), order

    find("#live-ticker").hover
    assert_ticker_states([ "paused" ])
    find(".hub__title").hover
    assert_ticker_states([ "running" ])

    page.execute_script("document.documentElement.dataset.motion = 'reduced'")
    assert_selector "#live-ticker[data-ticker-state=still]"
    assert_ticker_states([])
    assert_selector "#live-ticker [data-ticker-target=run] > .ticker__item", count: 12, visible: :all
    assert_no_selector "#live-ticker .ticker__run--copy", visible: :all
    assert_empty page.evaluate_script("document.querySelector('#live-ticker .live-marker__dot').getAnimations()")
  end

  def wait_until_renders(count)
    Timeout.timeout(Capybara.default_max_wait_time) do
      sleep 0.05 until page.evaluate_script("window.renders.length") >= count
    end
  end
end
