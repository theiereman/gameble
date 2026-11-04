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

  test "key 3 in the menu opens Social, with its mission and feed preview" do
    sign_in

    item("1").send_keys("3")
    assert_current_path social_path(locale: :en)
    assert_selector ".social h1.social__title", text: /SOCIAL/i
    assert_selector "#community-goal"
    assert_selector "#social-feed-preview"
  end

  test "key 6 swaps the menu for the extras in place; Escape or the back row brings the menu back" do
    sign_in

    item("1").send_keys("6")
    assert_selector "#hub-menu-extras .menu-item--back:focus"
    assert_no_selector ".hub-menu .menu-item", text: /OPEN A CAPSULE/i
    assert_selector "#hub-menu-extras a.menu-item[href='https://github.com/theiereman/gameble'][target=_blank]", text: /GITHUB/i

    find("#hub-menu-extras .menu-item--back").send_keys(:escape)
    assert_no_selector "#hub-menu-extras"
    assert_selector ".hub-menu button.menu-item[aria-expanded=false]:focus", text: /EXTRAS/i

    find(".hub-menu button.menu-item[aria-keyshortcuts='6']").click
    find("#hub-menu-extras .menu-item--back").click
    assert_selector ".hub-menu .menu-item", text: /OPEN A CAPSULE/i

    item("6").send_keys("6")
    find("#hub-menu-extras .menu-item--back").send_keys("1")
    assert_current_path how_it_works_path(locale: :en)

    find(".top-bar__home").click
    assert_selector "#hub-menu-extras a.menu-item[aria-keyshortcuts='1']:focus"
  end
end
