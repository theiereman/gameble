require "application_system_test_case"
require_relative "../support/steam_sign_in"

# Le Grand Inventaire's main path: the scope chip re-reads the screen and
# keeps the focus, the grid narrows to the cards still to discover, a card
# opens its detail whose back returns to the screen, and on a phone each tab
# shows its view and takes the focus to its heading.
class GrandInventoryTest < ApplicationSystemTestCase
  include SteamSignIn

  setup do
    @player = accounts_players(:player)
    game_first_discoveries(:legendary_card_one).destroy!
    game_first_discoveries(:rare_card_one).update!(player_id: @player.id, discovered_at: Time.current)
    mock_steam_sign_in(@player.steam_id)
  end

  def assert_focused(selector)
    eventually("the focus is not on #{selector}") { evaluate_script("document.activeElement?.matches(#{selector.to_json})") }
  end

  def open_state_sheet
    find("a.filter-row__pastille[href='#filters-state']").click
    eventually("the state sheet should be a modal dialog") { evaluate_script("document.querySelector('dialog#filters-state').matches(':modal')") }
    wait_for_dialog_to_finish_opening("dialog#filters-state")
  end

  test "a player switches to the current season, narrows the grid to the cards to discover, opens one and comes back; on a phone the tabs switch views" do
    visit home_path(locale: :en)
    click_steam_sign_in
    assert_signed_in
    visit grand_inventory_path(locale: :en)

    assert_selector ".grand-inventory__found", text: "4"
    assert_selector "#collection-slots li:first-child .grand-inventory-slot__badge", text: "YOU"

    chip = find("[role=group] button", text: /\ACurrent season\z/i)
    chip.click
    assert_selector "[role=group] button[aria-pressed=true]", text: /\ACurrent season\z/i
    assert_selector "[data-grand-inventory-target=status]", text: "Current season: 4 cards discovered of 5", visible: :all
    assert_focused "[role=group] button[aria-pressed=true]"
    eventually("the address should keep the scope") { current_url.include?("seasons=current") }

    open_state_sheet
    within("dialog#filters-state") { find(".filter-chip__text", text: /\ATo discover\z/i).click }
    assert_selector ".collection-grid > li", count: 1
    within("dialog#filters-state") { find("button.modal__close").click }

    find("#collection-slots .card-link[aria-label='Golden Crown, 1998, Legendary, to discover']").click
    back = find(".top-bar__phone-back", visible: :all)
    assert_equal "Great Inventory", back.text(:all).squish
    visit back[:href]
    assert_selector "[role=group] button[aria-pressed=true]", text: /\ACurrent season\z/i

    resize_to(390, 844)
    find("nav.grand-inventory__tabs a.tabs__tab", text: /\ASets\z/i).click
    assert_selector "nav.grand-inventory__tabs .tabs__tab--current", text: /\ASets\z/i
    assert_focused "#grand-inventory-sets-heading"
    assert_selector ".grand-inventory__sets-all", visible: true
    assert_no_selector "#collection-slots", visible: true
  end
end
