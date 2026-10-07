require "application_system_test_case"

# The trades screen in a browser (story 5.6; EXPERIENCE.md, Échanges, Trades
# on the phone): on a desktop the list beside the board, the actions as
# forms and the badge falling as the player answers; on a phone the list,
# then the board alone with "◀ Liste"; a visitor gets the sign-in panel.
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
    fill_in "Copies of Portal", with: "2"
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

  test "a visitor is led to the sign-in panel from menu 03" do
    visit home_path(locale: :en)

    find(".hub-menu button.menu-item[aria-keyshortcuts='3']").click

    assert_selector "#sign-in-panel", visible: true
  end
end
