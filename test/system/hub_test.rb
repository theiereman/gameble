require "application_system_test_case"
require_relative "../support/game_packs"
require_relative "../support/steam_sign_in"

# The hub, "Pont de commandement": the menu's number keys and the item
# focused on the way back.
class HubTest < ApplicationSystemTestCase
  include GamePacks
  include SteamSignIn

  setup do
    @player = accounts_players(:player)
    mock_steam_sign_in(@player.steam_id)
  end

  def focused_item
    page.evaluate_script("document.activeElement.getAttribute('aria-keyshortcuts')")
  end

  def sign_in
    visit home_path(locale: :en)
    click_steam_sign_in
    assert_signed_in
    assert_current_path home_path(locale: :en)
  end

  def item(key)
    find(".hub-menu .menu-item[aria-keyshortcuts='#{key}']")
  end


  test "number keys act only inside the menu, never on a disabled item; the item used is focused on the way back" do
    create_pack(@player)
    sign_in

    item("1").send_keys("0")
    assert_current_path home_path(locale: :en)
    find("body").send_keys("2")
    assert_current_path home_path(locale: :en)

    item("1").send_keys("2")
    assert_current_path library_path(locale: :en)

    find(".top-bar__home").click
    assert_current_path home_path(locale: :en)
    assert_selector ".hub-menu"
    assert_equal "2", focused_item

    # Only once: a later visit focuses nothing.
    visit home_path(locale: :en)
    assert_selector ".hub-menu"
    assert_nil focused_item
  end
end
