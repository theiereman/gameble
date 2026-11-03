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
end
