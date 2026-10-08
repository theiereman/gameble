require "application_system_test_case"

class TradesTest < ApplicationSystemTestCase
  setup do
    @hugo = accounts_players(:player)
    @lea = accounts_players(:moderator)
    @max = accounts_players(:administrator)
    @hugo.update!(persona_name: "Hugo")
    @lea.update!(persona_name: "Lea")
    @max.update!(persona_name: "Max")
    @portal = catalog_card_seasons(:portal_one).id
    @depths = catalog_card_seasons(:rare_card_one).id
    [ @lea, @max ].each { befriend(@hugo, it) }
    hold(@hugo, @portal, 4)
    hold(@lea, @depths, 2)
    hold(@max, @depths, 1)
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

  def hold(player, card_season_id, quantity)
    Game::Holding.create!(player_id: player.id, card_season_id:, quantity:, reserved: 0)
  end

  def propose(player, recipient, offer:, request:)
    Game::ProposeTrade.new.call(player:, recipient:, offer:, request:).value!
  end

  def sign_in(player)
    OmniAuth.config.mock_auth[:steam] = OmniAuth::AuthHash.new(provider: "steam", uid: "https://steamcommunity.com/openid/id/#{player.steam_id}")
    visit home_path(locale: :en)
    click_steam_sign_in
    assert_signed_in
  end

  test "on a desktop a player answers two trades and the badge falls" do
    from_lea = propose(@lea, @hugo, offer: { @depths => 1 }, request: { @portal => 2 })
    propose(@max, @hugo, offer: { @depths => 1 }, request: { @portal => 1 })
    sign_in @hugo

    assert_selector ".hub-menu a.menu-item .menu-item__badge--alert", text: "2"
    find(".hub-menu a.menu-item[aria-keyshortcuts='3']").click

    assert_selector ".trades__group", text: /WAITING FOR YOU/i
    assert_selector ".trade-row", count: 2
    assert_selector ".trades__list", visible: true
    assert_selector ".trade-board", visible: true

    find(".trade-row", text: /LEA/i).click
    assert_selector ".trade-board__title", text: "Trade with Lea"
    within(".trade-board") { click_on "Accept" }
    assert_selector ".toast", text: /Blue Depths joins your collection/
    assert_selector ".trade-board .trade-chip--lime", text: /DONE/i

    find(".trade-row", text: /MAX/i).click
    within(".trade-board") { click_on "Counter" }
    assert_selector ".trade-side--editing", count: 2
    within(".trade-side--own") do
      assert_selector ".stepper[aria-valuenow='1'][aria-valuemax='2']"
      find(".stepper__button--more").click
      assert_selector ".stepper[aria-valuenow='2']"
    end
    click_on "Send the counter-proposal"
    assert_selector ".toast", text: /Max has 7 days to answer/
    assert_selector ".trade-board .trade-chip--accent", text: /WAITING/i

    visit home_path(locale: :en)
    assert_selector ".hub-menu a.menu-item .menu-item__badge--zero", text: "0"
    assert_equal "accepted", Game::Trade.find(from_lea.id).status
  end

  test "on a phone the board slides over the list, back with List" do
    resize_to(390, 844)
    trade = propose(@lea, @hugo, offer: { @depths => 1 }, request: { @portal => 2 })
    sign_in @hugo

    assert_selector ".tab-bar a.tab-bar__tab .tab-bar__badge--alert", text: "1"
    find(".tab-bar a.tab-bar__tab[href='/en/trades']").click
    assert_selector ".trade-row", visible: true
    assert_no_selector ".trade-board", visible: true

    find(".trade-row", text: /LEA/i).click
    assert_current_path trade_path(token: trade.token, locale: :en)
    assert_selector ".trade-board", visible: true
    assert_no_selector ".trades__list", visible: true
    assert_selector ".trade-board__actions", visible: true
    within(".trade-board") { click_on "Decline" }
    assert_selector ".toast", text: /Your answer was sent to Lea/
    assert_no_selector ".tab-bar__badge"
    assert page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth"), "no sideways scroll"

    find(".toast .toast__close").click
    find(".top-bar__phone-back", text: /LIST/i).click
    assert_current_path trades_path(locale: :en)
    assert_selector ".trade-row", text: /declined/, visible: true
  end

  def pick_toggle(title) = find(".trade-picker .trade-pick__toggle[aria-label^='#{title},']")

  def place_picks
    within(".trade-picker") { click_on "Place", exact: true }
    assert_no_selector ".trade-picker", visible: true
  end

  test "on a desktop the picker places cards and quantities on both sides, within the limits" do
    soldier, hills, crown = %i[common_card_one uncommon_card_one legendary_card_one].map { catalog_card_seasons(it).id }
    hold(@hugo, soldier, 1)
    hold(@hugo, crown, 1)
    [ soldier, crown, @portal ].each { hold(@lea, it, 1) }
    hold(@lea, hills, 3)
    propose(@hugo, @max, offer: { crown => 1, @portal => 1 }, request: { @depths => 1 })
    trade = propose(@lea, @hugo, offer: { @depths => 1 }, request: { @portal => 2 })
    sign_in @hugo

    visit counter_trade_path(token: trade.token, locale: :en)
    within(".trade-side--own") { assert_selector ".stepper[aria-valuenow='2'][aria-valuemax='3']" }

    find(".trade-side--own .trade-add").click
    assert_selector "#trade-picker-title", text: /Place my cards/i
    assert_selector ".trade-pick__toggle[aria-label='Portal, 4 copies, 1 reserved in another trade'][aria-pressed='true']"
    within(".trade-pick", text: /×4/) do
      assert_selector ".trade-pick__reserved", text: /Reserved/i
      assert_selector ".stepper[aria-valuemax='3']"
    end
    crown_toggle = pick_toggle("Golden Crown")
    assert_equal "true", crown_toggle["aria-disabled"]
    assert_selector ".trade-pick__card--unavailable .trade-pick__reserved", text: /Reserved/i
    crown_toggle.click
    assert_equal "false", crown_toggle["aria-pressed"]
    pick_toggle("Tin Soldier").click
    assert_selector ".trade-picker__count", text: "2 cards · 3 copies (4 cards at most)"
    place_picks
    assert_no_selector ".trade-picker"
    within(".trade-side--own") do
      assert_selector ".trade-card__remove", count: 2
      assert_selector ".trade-side__count", text: "2 cards · 3 copies"
    end

    find(".trade-side--friend .trade-add").click
    assert_selector "#trade-picker-title", text: /Choose from Lea's collection/i
    pick_toggle("Green Hills").click
    within(".trade-pick", text: /×3/) { find(".stepper__button--more").click }
    assert_selector ".trade-picker .stepper[aria-valuenow='2'][aria-valuemax='3']"
    pick_toggle("Tin Soldier").click
    pick_toggle("Golden Crown").click
    pick_toggle("Portal").click
    assert_selector ".trade-picker__refusal", text: /4 cards at most · Remove a card before placing another\./i
    assert_equal "false", pick_toggle("Portal")["aria-pressed"]
    pick_toggle("Golden Crown").click
    place_picks
    within(".trade-side--friend") do
      assert_selector ".trade-card__remove", count: 3
      find(".trade-card__remove[aria-label='Remove Tin Soldier']").click
      assert_selector ".trade-card__remove", count: 2
    end

    click_on "Send the counter-proposal"
    assert_selector ".toast", text: /Lea has 7 days to answer/
    trade.reload
    assert_equal @hugo.id, trade.proposer_id
    assert_equal({ "offer" => [ [ soldier, 1 ], [ @portal, 2 ] ].sort, "request" => [ [ hills, 2 ], [ @depths, 1 ] ].sort },
      trade.items.group_by(&:side).transform_values { |items| items.map { [ it.card_season_id, it.quantity ] }.sort })
  end

  test "the picker filters its cards by title and rarity without touching the selection" do
    soldier, hills, crown = %i[common_card_one uncommon_card_one legendary_card_one].map { catalog_card_seasons(it).id }
    [ soldier, hills, crown, @portal ].each { hold(@lea, it, 1) }
    trade = propose(@lea, @hugo, offer: { @depths => 1 }, request: { @portal => 2 })
    sign_in @hugo
    visit counter_trade_path(token: trade.token, locale: :en)

    find(".trade-side--friend .trade-add").click
    assert_selector ".trade-pick", count: 5
    pick_toggle("Tin Soldier").click

    fill_in "Search by title", with: "PORT"
    assert_selector ".trade-pick", count: 1
    assert_selector ".trade-pick__toggle[aria-label^='Portal,']"
    assert_selector ".trade-picker__results", text: "1 card shown."
    assert_selector ".trade-picker__count", text: "2 cards · 2 copies (4 cards at most)"

    fill_in "Search by title", with: ""
    check "Legendary", allow_label_click: true
    check "Common", allow_label_click: true
    assert_selector ".trade-pick", count: 2
    assert_selector ".trade-pick__toggle[aria-label^='Golden Crown,']"
    assert_selector ".trade-pick__toggle[aria-label^='Tin Soldier,'][aria-pressed='true']"

    fill_in "Search by title", with: "portal"
    assert_no_selector ".trade-pick"
    assert_selector ".trade-picker__empty", text: /No card matches/
    assert_selector ".trade-picker__results", text: "No card shown."
    assert_selector ".trade-picker__count", text: "2 cards · 2 copies (4 cards at most)"

    click_on "Clear filters"
    assert_selector ".trade-pick", count: 5
    assert_equal "", find_field("Search by title").value
    assert_selector ".trade-picker input[type=search]:focus"
    assert_no_selector ".trade-picker__clear"

    check "Legendary", allow_label_click: true
    check "Common", allow_label_click: true
    assert_selector ".trade-pick", count: 2
    pick_toggle("Tin Soldier").send_keys(:arrow_right, :arrow_left)
    assert_selector ".trade-pick__toggle:focus[aria-label^='Tin Soldier,']"
    page.active_element.send_keys(:end)
    assert_selector ".trade-pick:last-child .trade-pick__toggle[tabindex='0']"
    uncheck "Legendary", allow_label_click: true
    uncheck "Common", allow_label_click: true
    place_picks
    within(".trade-side--friend") { assert_selector ".trade-card__remove[aria-label='Remove Tin Soldier']" }
  end

  test "the board and its picker work by keyboard" do
    soldier = catalog_card_seasons(:common_card_one).id
    hold(@hugo, soldier, 3)
    trade = propose(@lea, @hugo, offer: { @depths => 1 }, request: { @portal => 2 })
    sign_in @hugo
    visit counter_trade_path(token: trade.token, locale: :en)

    assert_selector ".trade-side--own .trade-add"
    assert page.evaluate_script("document.activeElement.matches('.trade-side--own .trade-add')"), "focus on the player's add slot"
    page.active_element.send_keys(:enter)
    assert_selector ".trade-picker"
    assert_equal "Portal", page.active_element["aria-label"].split(",").first
    page.active_element.send_keys(:arrow_left)
    assert_equal "Tin Soldier", page.active_element["aria-label"].split(",").first
    page.active_element.send_keys(:enter)
    assert_selector ".trade-pick__toggle[aria-label^='Tin Soldier,'][aria-pressed='true']"
    page.active_element.send_keys(:tab)
    assert_equal "spinbutton", page.active_element["role"]
    page.active_element.send_keys(:arrow_up)
    assert_selector ".trade-picker .stepper[aria-label='Copies of Tin Soldier'][aria-valuenow='2']"
    page.active_element.send_keys(:tab, :tab)
    assert_equal "Place", page.active_element.text(:all).strip
    page.active_element.send_keys(:enter)

    assert_no_selector ".trade-picker"
    assert_includes page.active_element[:class], "trade-add"
    within(".trade-side--own") { assert_selector ".stepper[aria-label='Copies of Tin Soldier'][aria-valuenow='2']" }

    find(".trade-side--own .trade-add").send_keys(:enter)
    assert_selector ".trade-picker"
    page.active_element.send_keys(:enter)
    page.active_element.send_keys(:escape)
    assert_no_selector ".trade-picker"
    assert_includes page.active_element[:class], "trade-add"
    within(".trade-side--own") { assert_selector ".trade-card__remove", count: 2 }

    find(".trade-side--own .trade-card__remove[aria-label='Remove Portal']").send_keys(:enter)
    assert_equal "Remove Tin Soldier", page.active_element["aria-label"]
  end

  test "on a phone the picker is a full-height sheet, and the send button waits for a card on each side" do
    resize_to(390, 844)
    hold(@lea, catalog_card_seasons(:uncommon_card_one).id, 2)
    trade = propose(@lea, @hugo, offer: { @depths => 1 }, request: { @portal => 2 })
    sign_in @hugo
    visit counter_trade_path(token: trade.token, locale: :en)

    find(".trade-side--own .trade-card__remove[aria-label='Remove Portal']").click
    assert_selector "#trade-send-reason", text: "Choose the cards on each side.", visible: true
    assert_selector "button[type=submit][disabled]", text: /Send the counter-proposal/i

    find(".trade-side--friend .trade-add").click
    assert_selector ".trade-picker__title-short", text: /Lea's cards/i, visible: true
    assert_no_selector ".trade-picker__title", visible: true
    height = page.evaluate_script("document.querySelector('.trade-picker').getBoundingClientRect().height")
    assert_in_delta page.evaluate_script("window.innerHeight"), height, 2
    assert page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth"), "no sideways scroll"
    pick_toggle("Green Hills").click
    place_picks

    find(".trade-side--own .trade-add").click
    pick_toggle("Portal").click
    place_picks
    assert_no_selector "#trade-send-reason", visible: true
    click_on "Send the counter-proposal"
    assert_selector ".toast", text: /Lea has 7 days to answer/
  end

  def record_animations
    page.execute_script(<<~JS)
      window.recordedFrames = []
      const animate = Element.prototype.animate
      Element.prototype.animate = function (frames, options) {
        window.recordedFrames.push(JSON.stringify(frames))
        return animate.call(this, frames, options)
      }
    JS
  end

  def recorded_frames = page.evaluate_script("window.recordedFrames")

  def draft_entries = page.evaluate_script("Object.keys(localStorage).filter((key) => key.startsWith('gameble:trade-draft:'))")

  test "a draft is kept in the browser until it is sent, the friend counters it in place, and accepting plays the swap" do
    hills = catalog_card_seasons(:uncommon_card_one).id
    hold(@lea, hills, 2)
    sign_in @hugo

    visit friends_path(locale: :en)
    click_on "Lea"
    within(".friend-profile") { click_on "Propose a trade" }
    assert_selector ".trade-board .trade-chip--accent", text: /DRAFT/i
    assert_selector ".trade-board__expiry", text: "Valid for 7 days once sent"
    assert page.evaluate_script("document.activeElement.id === 'trade-board-heading'"), "focus on the board heading"
    assert_selector "button[type=submit][disabled]", text: /Send the proposal/i
    find(".trade-side--friend .trade-add").click
    pick_toggle("Blue Depths").click
    place_picks
    find(".trade-side--own .trade-add").click
    pick_toggle("Portal").click
    place_picks
    within(".trade-side--own") do
      find(".stepper__button--more").click
      assert_selector ".stepper[aria-valuenow='2']"
    end
    assert_equal 1, draft_entries.size

    visit home_path(locale: :en)
    assert_signed_in
    assert_equal 0, Game::Trade.count
    visit new_trade_path(locale: :en, friend: @lea.token)
    within(".trade-side--own") { assert_selector ".stepper[aria-label='Copies of Portal'][aria-valuenow='2']" }
    within(".trade-side--friend") { assert_selector ".trade-card__remove[aria-label='Remove Blue Depths']" }
    click_on "Send the proposal"
    assert_selector ".toast", text: /Lea has 7 days to answer/
    assert_selector ".trade-board .trade-chip--accent", text: /WAITING/i
    assert_empty draft_entries
    trade = Game::Trade.sole
    assert_equal [ [ "offer", @portal, 2 ], [ "request", @depths, 1 ] ], trade.items.order(:side).map { [ it.side, it.card_season_id, it.quantity ] }

    find(".toast .toast__close").click
    sign_out
    assert_signed_out
    sign_in @lea
    visit trade_path(token: trade.token, locale: :en)
    page.execute_script("window.stayedOnPage = true")
    within(".trade-board") { click_on "Counter" }
    assert_selector ".trade-side--editing", count: 2
    assert_selector ".trade-board .trade-chip--accent", text: /EDITING/i
    assert_current_path counter_trade_path(token: trade.token, locale: :en)
    assert page.evaluate_script("document.activeElement.matches('.trade-side--own .trade-add')"), "focus on the player's add slot"

    click_on "Discard the changes"
    assert_no_selector ".trade-side--editing"
    assert_no_selector "#trade-undo-dialog", visible: true
    assert_current_path trade_path(token: trade.token, locale: :en)

    within(".trade-board") { click_on "Counter" }
    find(".trade-side--own .trade-card__remove[aria-label='Remove Blue Depths']").click
    find(".trade-side--own .trade-add").click
    pick_toggle("Green Hills").click
    place_picks
    click_on "Discard the changes"
    within("#trade-undo-dialog") { click_on "Keep editing" }
    assert_no_selector "#trade-undo-dialog", visible: true
    within(".trade-side--own") { assert_selector ".trade-card__remove[aria-label='Remove Green Hills']" }
    click_on "Discard the changes"
    within("#trade-undo-dialog") { click_on "Discard the changes" }
    assert_no_selector ".trade-side--editing"
    within(".trade-side--own") { assert_selector ".card", text: /Blue Depths/i }
    assert_selector ".trade-board .trade-chip--alert", text: /YOUR TURN/i
    assert_empty draft_entries
    assert page.evaluate_script("window.stayedOnPage === true"), "the counter-proposal opened and closed in place"

    within(".trade-board") { click_on "Counter" }
    find(".trade-side--own .trade-card__remove[aria-label='Remove Blue Depths']").click
    find(".trade-side--own .trade-add").click
    pick_toggle("Green Hills").click
    place_picks
    click_on "Send the counter-proposal"
    assert_selector ".toast", text: /Hugo has 7 days to answer/
    assert_empty draft_entries

    find(".toast .toast__close").click
    sign_out
    assert_signed_out
    sign_in @hugo
    visit trade_path(token: trade.token, locale: :en)
    record_animations
    within(".trade-board") { click_on "Accept" }
    assert_selector ".trade-board .trade-chip--lime", text: /DONE/i
    assert_selector ".trade-board__message:focus", text: "Trade done."
    flights = recorded_frames.select { it.include?("translate(") }
    assert_equal 2, flights.size, "both stacks fly across"
    assert flights.all? { it.include?("scale(1.12, 0.86)") }, "and squash as they land"
    within(".trade-side--own") do
      assert_selector ".card", text: /Green Hills/i
      assert_selector ".trade-card__new", text: /NEW/i
    end
    within(".trade-side--friend") { assert_selector ".card", text: /Portal/i }
  end

  test "with Animations réduites the swap is a crossfade" do
    @hugo.update!(reduced_motion: true)
    trade = propose(@lea, @hugo, offer: { @depths => 1 }, request: { @portal => 2 })
    sign_in @hugo
    visit trade_path(token: trade.token, locale: :en)
    record_animations

    within(".trade-board") { click_on "Accept" }

    assert_selector ".trade-board .trade-chip--lime", text: /DONE/i
    assert_selector ".trade-board__message:focus", text: "Trade done."
    frames = recorded_frames
    assert_not frames.any? { it.include?("translate(") }, "no card moves"
    assert_equal 2, frames.count { it.include?("opacity") }
  end

  test "a draft or a counter-proposal refused by the server keeps the picks still possible" do
    hills, soldier = %i[uncommon_card_one common_card_one].map { catalog_card_seasons(it).id }
    hold(@lea, hills, 2)
    sign_in @hugo
    visit new_trade_path(locale: :en, friend: @lea.token)
    find(".trade-side--friend .trade-add").click
    pick_toggle("Blue Depths").click
    pick_toggle("Green Hills").click
    place_picks
    find(".trade-side--own .trade-add").click
    pick_toggle("Portal").click
    place_picks
    Game::Holding.where(player_id: @lea.id, card_season_id: hills).update_all(quantity: 0)

    click_on "Send the proposal"

    assert_selector ".trade-board__error", text: I18n.t("errors.game.invalid_request", locale: :en)
    assert_selector ".trade-board .trade-chip--accent", text: /DRAFT/i
    within(".trade-side--friend") do
      assert_selector ".trade-card__remove", count: 1
      assert_selector ".trade-card__remove[aria-label='Remove Blue Depths']"
    end
    within(".trade-side--own") { assert_selector ".trade-card__remove[aria-label='Remove Portal']" }

    hold(@hugo, soldier, 1)
    Game::Holding.where(player_id: @lea.id, card_season_id: hills).update_all(quantity: 1)
    from_lea = propose(@lea, @hugo, offer: { @depths => 1 }, request: { @portal => 1 })
    visit trade_path(token: from_lea.token, locale: :en)
    within(".trade-board") { click_on "Counter" }
    find(".trade-side--friend .trade-add").click
    pick_toggle("Green Hills").click
    place_picks
    find(".trade-side--own .trade-card__remove[aria-label='Remove Portal']").click
    find(".trade-side--own .trade-add").click
    pick_toggle("Tin Soldier").click
    place_picks
    Game::Holding.where(player_id: @lea.id, card_season_id: hills).update_all(quantity: 0)

    click_on "Send the counter-proposal"

    assert_selector ".trade-board__error", text: I18n.t("errors.game.invalid_request", locale: :en)
    assert_current_path counter_trade_path(token: from_lea.token, locale: :en)
    within(".trade-side--friend") do
      assert_selector ".trade-card__remove", count: 1
      assert_selector ".trade-card__remove[aria-label='Remove Blue Depths']"
    end
    within(".trade-side--own") do
      assert_selector ".trade-card__remove", count: 1
      assert_selector ".trade-card__remove[aria-label='Remove Tin Soldier']"
    end
  end

  test "a draft with a friend already trading opens that trade instead" do
    trade = propose(@lea, @hugo, offer: { @depths => 1 }, request: { @portal => 2 })
    sign_in @hugo

    visit new_trade_path(locale: :en, friend: @lea.token)

    assert_current_path trade_path(token: trade.token, locale: :en)
    assert_selector ".trade-board__error", text: "A trade is already open with Lea."
  end

  test "abandoning a draft forgets it" do
    sign_in @hugo
    visit new_trade_path(locale: :en, friend: @max.token)
    find(".trade-side--own .trade-add").click
    pick_toggle("Portal").click
    place_picks
    assert_equal 1, draft_entries.size

    click_on "Abandon"

    assert_current_path trades_path(locale: :en)
    assert_empty draft_entries
    visit new_trade_path(locale: :en, friend: @max.token)
    assert_selector ".trade-side--own .trade-add"
    assert_no_selector ".trade-card__remove"
  end

  test "a visitor is led to the sign-in panel from menu 03" do
    visit home_path(locale: :en)

    find(".hub-menu button.menu-item[aria-keyshortcuts='3']").click

    assert_selector "#sign-in-panel", visible: true
  end
end
