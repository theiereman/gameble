require "application_system_test_case"
require_relative "../support/custom_sets"
require_relative "../support/holdings"
require_relative "../support/steam_sign_in"

# A board opened from a suggestion: looking writes nothing, the first change
# or send makes it the friend's stored draft at the friend's plain address.
class TradeSuggestionBoardsTest < ApplicationSystemTestCase
  include CustomSets
  include Holdings
  include SteamSignIn

  setup do
    @hugo = accounts_players(:player)
    @lea = accounts_players(:moderator)
    @hugo.update!(persona_name: "Hugo")
    @lea.update!(persona_name: "Lea")
    befriend(@hugo, @lea)
    soldier = catalog_card_seasons(:common_card_one).id
    @hills = catalog_card_seasons(:uncommon_card_one).id
    @depths = catalog_card_seasons(:rare_card_one).id
    hold(@hugo, soldier)
    hold(@hugo, catalog_card_seasons(:portal_one).id, 2)
    card_ids = Catalog::CardSeason.where(id: [ soldier, @hills, @depths ]).pluck(:card_id)
    Game::AddGoal.new.call(player: @hugo, custom_set: create_custom_set(@hugo, card_ids:).token).value!
    hold(@lea, @depths, 2)
    hold(@lea, @hills, 2)
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

  def store_draft_for_lea
    visit new_trade_path(locale: :en, friend: @lea.token)
    find(".trade-side--own .trade-add").click
    find(".trade-picker .trade-pick__toggle[aria-label^='Portal,']").click
    within(".trade-picker") { click_on "Place", exact: true }
    assert_no_selector ".trade-picker", visible: true
    eventually("the draft for Lea is stored") { lea_draft.present? }
    lea_draft
  end

  def open_suggestion
    visit trades_path(locale: :en)
    find(".trade-suggestion__opener").click
    assert_current_path new_trade_path(locale: :en, friend: @lea.token, take: %w[blue-depths--s1 green-hills--s1])
  end

  def plain_board_path = new_trade_path(locale: :en, friend: @lea.token)

  test "opening a suggestion, then going Back or abandoning it, stores nothing and leaves the suggestion listed" do
    sign_in @hugo

    open_suggestion
    assert_selector ".trade-side--friend .trade-card__remove[aria-label='Remove Green Hills']"
    page.go_back
    assert_current_path trades_path(locale: :en)
    assert_selector ".trade-suggestion", count: 1
    assert_nil lea_draft

    find(".trade-suggestion__opener").click
    assert_selector ".trade-side--friend .trade-card__remove[aria-label='Remove Green Hills']"
    click_on "Abandon"
    assert_current_path trades_path(locale: :en)
    assert_selector ".trade-suggestion", count: 1
    assert_nil lea_draft
  end

  test "removing a card from the prefilled board stores the board for the friend at the plain address, which a reload shows" do
    sign_in @hugo

    open_suggestion
    find(".trade-side--friend .trade-card__remove[aria-label='Remove Green Hills']").click

    assert_current_path plain_board_path
    stored = { "take" => [ { "key" => "blue-depths--s1", "quantity" => 1 } ], "give" => [] }
    eventually("the board is stored as Lea's draft") { lea_draft.present? && JSON.parse(lea_draft) == stored }

    page.refresh
    within(".trade-side--friend") do
      assert_selector ".trade-card__remove[aria-label='Remove Blue Depths']"
      assert_no_selector ".trade-card__remove[aria-label='Remove Green Hills']"
    end
    assert_no_selector ".trade-side--own .trade-card__remove"
  end

  test "a friend whose board is stored as a draft leaves the suggestions of the trade list" do
    sign_in @hugo
    visit trades_path(locale: :en)
    assert_selector ".trade-suggestion", count: 1

    store_draft_for_lea
    visit trades_path(locale: :en)

    assert_no_selector ".trade-suggestions"
  end

  test "sending the prefilled board unchanged proposes the suggested cards, and Back lands on an empty plain board" do
    sign_in @hugo

    open_suggestion
    assert_selector ".trade-side--friend .trade-card__remove[aria-label='Remove Green Hills']"
    click_on "Send the proposal"

    assert_selector ".toast .toast__title", text: /PROPOSAL SENT/i
    trade = Game::Trade.sole
    assert_equal [ [ "request", @hills, 1 ], [ "request", @depths, 1 ] ].sort, trade.items.map { [ it.side, it.card_season_id, it.quantity ] }.sort
    assert_current_path trade_path(locale: :en, token: trade.token)
    eventually("the sent draft is forgotten") { lea_draft.nil? }

    page.go_back
    assert_current_path plain_board_path
    assert_selector ".trade-side--friend.trade-side--editing"
    assert_no_selector ".trade-side--friend .trade-card__remove"
    assert_nil lea_draft
  end

  test "a refused send of the prefilled board lands on the plain board, which keeps what was sent as the stored draft" do
    sign_in @hugo

    open_suggestion
    assert_selector ".trade-side--friend .trade-card__remove[aria-label='Remove Green Hills']"
    Game::Holding.where(player_id: @lea.id, card_season_id: @hills).delete_all
    click_on "Send the proposal"

    assert_selector ".toast", text: "Ask for one to four different cards"
    assert_current_path plain_board_path
    assert_equal 0, Game::Trade.count
    still_held = { "take" => [ { "key" => "blue-depths--s1", "quantity" => 1 } ], "give" => [] }
    eventually("the sent board, less the card Lea no longer holds, is her stored draft") { lea_draft.present? && JSON.parse(lea_draft) == still_held }
    within(".trade-side--friend") do
      assert_selector ".trade-card__remove[aria-label='Remove Blue Depths']"
      assert_no_selector ".trade-card__remove[aria-label='Remove Green Hills']"
    end
  end

  test "a card the friend traded away after the list was read is not placed when the opener is followed" do
    sign_in @hugo
    visit trades_path(locale: :en)
    assert_selector ".trade-suggestion__summary", text: "Blue Depths, Green Hills · for Lea to choose in return"

    Game::Holding.find_by!(player_id: @lea.id, card_season_id: @hills).update!(reserved: 2)
    find(".trade-suggestion__opener").click

    assert_current_path new_trade_path(locale: :en, friend: @lea.token, take: %w[blue-depths--s1 green-hills--s1])
    within(".trade-side--friend.trade-side--editing") do
      assert_selector ".trade-card__remove[aria-label='Remove Blue Depths']"
      assert_no_selector ".trade-card__remove[aria-label='Remove Green Hills']"
    end
  end
end
