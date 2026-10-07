require "application_system_test_case"

# The trades screen in a browser (stories 5.6, 5.7; EXPERIENCE.md, Échanges,
# Card picker, Trades on the phone): on a desktop the list beside the board,
# the actions as forms and the badge falling as the player answers; on a
# phone the list, then the board alone with "◀ Liste"; the counter-proposal's
# trade board island with its card picker and steppers, by pointer, by
# keyboard and on a phone; a visitor gets the sign-in panel.
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

  # The card picker's button for a card, by the start of its accessible name.
  def pick_toggle(title) = find(".trade-picker .trade-pick__toggle[aria-label^='#{title},']")

  test "on a desktop the picker places cards and quantities on both sides, within the limits" do
    soldier, hills, crown = %i[common_card_one uncommon_card_one legendary_card_one].map { catalog_card_seasons(it).id }
    hold(@hugo, soldier, 1)
    hold(@hugo, crown, 1)
    [ soldier, crown, @portal ].each { hold(@lea, it, 1) }
    hold(@lea, hills, 3)
    # Hugo's only Golden Crown and one of his four Portal are reserved in his trade with Max.
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
    click_on "Place"
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
    click_on "Place"
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

  test "the board and its picker work by keyboard" do
    soldier = catalog_card_seasons(:common_card_one).id
    hold(@hugo, soldier, 3)
    trade = propose(@lea, @hugo, offer: { @depths => 1 }, request: { @portal => 2 })
    sign_in @hugo
    visit counter_trade_path(token: trade.token, locale: :en)

    # Countering puts the focus on the add slot of the player's side.
    assert_selector ".trade-side--own .trade-add"
    assert page.evaluate_script("document.activeElement.matches('.trade-side--own .trade-add')"), "focus on the player's add slot"
    page.active_element.send_keys(:enter)
    assert_selector ".trade-picker"
    # The grid is one tab stop, on the card already placed: Portal, after Tin Soldier.
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

    # Esc discards the picker's choice and gives the focus back.
    find(".trade-side--own .trade-add").send_keys(:enter)
    assert_selector ".trade-picker"
    page.active_element.send_keys(:enter)
    page.active_element.send_keys(:escape)
    assert_no_selector ".trade-picker"
    assert_includes page.active_element[:class], "trade-add"
    within(".trade-side--own") { assert_selector ".trade-card__remove", count: 2 }

    # "✕" by keyboard: the focus goes to the next card on that side.
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
    click_on "Place"

    find(".trade-side--own .trade-add").click
    pick_toggle("Portal").click
    click_on "Place"
    assert_no_selector "#trade-send-reason", visible: true
    click_on "Send the counter-proposal"
    assert_selector ".toast", text: /Lea has 7 days to answer/
  end

  test "a visitor is led to the sign-in panel from menu 03" do
    visit home_path(locale: :en)

    find(".hub-menu button.menu-item[aria-keyshortcuts='3']").click

    assert_selector "#sign-in-panel", visible: true
  end
end
