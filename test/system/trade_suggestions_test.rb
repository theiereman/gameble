require "application_system_test_case"
require_relative "../support/custom_sets"
require_relative "../support/game_sets"
require_relative "../support/holdings"
require_relative "../support/steam_sign_in"

class TradeSuggestionsTest < ApplicationSystemTestCase
  include CustomSets
  include GameSets
  include Holdings
  include SteamSignIn

  setup do
    @hugo = accounts_players(:player)
    @lea = accounts_players(:moderator)
    @max = accounts_players(:administrator)
    @hugo.update!(persona_name: "Hugo")
    @lea.update!(persona_name: "Lea")
    @max.update!(persona_name: "Max")
    [ @lea, @max ].each { befriend(@hugo, it) }
    soldier = catalog_card_seasons(:common_card_one).id
    @hills = catalog_card_seasons(:uncommon_card_one).id
    @depths = catalog_card_seasons(:rare_card_one).id
    hold(@hugo, soldier)
    hold(@hugo, catalog_card_seasons(:portal_one).id, 2)
    card_ids = Catalog::CardSeason.where(id: [ soldier, @hills, @depths ]).pluck(:card_id)
    Game::AddGoal.new.call(player: @hugo, custom_set: create_custom_set(@hugo, card_ids:).token).value!
    hold(@lea, @depths, 2)
    hold(@lea, @hills, 2)
    hold(@max, @depths, 1, reserved: 1)
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

  def lea_draft = page.evaluate_script("localStorage.getItem('gameble:trade-draft:#{@hugo.token}:#{@lea.token}')")

  def focused?(selector) = page.evaluate_script("document.activeElement?.matches(#{selector.to_json}) === true")

  test "a suggestion opens on the board prefilled, leaving nothing stored" do
    sign_in @hugo

    visit trades_path(locale: :en)
    within(".trade-suggestions") do
      assert_selector ".trade-suggestions__heading", text: /SUGGESTIONS/i
      assert_selector ".trade-suggestion", count: 1
      assert_selector ".trade-suggestion__summary", text: "Blue Depths, Green Hills · for Lea to choose in return"
    end
    find(".trade-suggestion__opener").click

    assert_current_path new_trade_path(locale: :en, friend: @lea.token, take: %w[blue-depths--s1 green-hills--s1])
    within(".trade-side--friend.trade-side--editing") do
      assert_selector ".trade-card__remove[aria-label='Remove Blue Depths']"
      assert_selector ".trade-card__remove[aria-label='Remove Green Hills']"
    end
    assert_no_selector ".trade-side--own.trade-side--editing .trade-card__remove"
    assert_selector ".trade-suggestion--current .trade-suggestion__opener[aria-current='true']"
    eventually("focus on the board heading") { focused?("#trade-board-heading") }
    assert_nil lea_draft

    click_on "Abandon"
    assert_current_path trades_path(locale: :en)
    assert_selector ".trade-suggestion", count: 1
    assert_nil lea_draft
  end

  test "ENVOYER sends the suggestion, the title-only toast shows, and the focus lands on the sent trade's row" do
    sign_in @hugo

    visit trades_path(locale: :en)
    find(".trade-suggestion__opener").send_keys(:tab)
    eventually("ENVOYER after the opener") { focused?(".trade-suggestion__send button") }
    assert_selector ".trade-suggestions[data-live-refresh-hold]", visible: :all
    find(".trade-suggestion__send button", text: /SEND/i).click

    assert_selector ".toast .toast__title", text: /PROPOSAL FORWARDED/i
    assert_no_selector ".toast .toast__message"
    assert_no_selector ".trade-suggestions"
    trade = Game::Trade.sole
    assert_equal [ [ "request", @hills, 1 ], [ "request", @depths, 1 ] ].sort, trade.items.map { [ it.side, it.card_season_id, it.quantity ] }.sort
    eventually("focus on the sent trade's row") { focused?(".trade-row[href$='#{trade.token}']") }
    assert_nil lea_draft
  end

  test "after ENVOYER the focus lands on the next suggestion's opener, which holds live refresh through a window blur" do
    Game::Holding.find_by!(player_id: @lea.id, card_season_id: @hills).update!(reserved: 2)
    crown = catalog_card_seasons(:legendary_card_one).id
    crown_card_ids = Catalog::CardSeason.where(id: [ catalog_card_seasons(:common_card_one).id, crown, *unheld_cards(1) ]).pluck(:card_id)
    Game::AddGoal.new.call(player: @hugo, custom_set: create_custom_set(@hugo, name: "Crown run", card_ids: crown_card_ids).token).value!
    hold(@max, crown, 2)
    sign_in @hugo

    visit trades_path(locale: :en)
    assert_selector ".trade-suggestion", count: 2
    first(".trade-suggestion__send button", text: /SEND/i).click

    assert_selector ".toast .toast__title", text: /PROPOSAL FORWARDED/i
    assert_selector ".trade-suggestion", count: 1
    assert_selector ".trade-suggestion__summary", text: "Golden Crown · for Max to choose in return"
    eventually("focus on the remaining suggestion's opener") { focused?(".trade-suggestion__opener") }
    assert_selector ".trade-suggestions[data-live-refresh-hold]", visible: :all

    page.execute_script("document.activeElement.dispatchEvent(new FocusEvent('focusout', { bubbles: true, relatedTarget: null }))")
    held_after_blur = page.evaluate_async_script(<<~JS)
      const done = arguments[arguments.length - 1]
      setTimeout(() => done(document.querySelector(".trade-suggestions").hasAttribute("data-live-refresh-hold")), 100)
    JS
    assert held_after_blur, "a window blur keeps the hold while the focus stays in the section"

    page.execute_script("document.activeElement.blur()")
    assert_no_selector ".trade-suggestions[data-live-refresh-hold]", visible: :all
  end

  test "on a phone the row and ENVOYER are touch targets, and the list does not scroll sideways" do
    resize_to(390, 844)
    sign_in @hugo

    visit trades_path(locale: :en)

    row = find(".trade-suggestion")
    send = find(".trade-suggestion__send button")
    assert_operator row.rect.height, :>=, 44
    assert_operator send.rect.height, :>=, 44
    assert_operator send.rect.y - row.rect.y, :>=, 8
    assert_operator (row.rect.x + row.rect.width) - (send.rect.x + send.rect.width), :>=, 8
    assert page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth"), "no sideways scroll"
  end
end
