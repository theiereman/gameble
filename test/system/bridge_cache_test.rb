require "application_system_test_case"
require_relative "../support/steam_sign_in"

class BridgeCacheTest < ApplicationSystemTestCase
  include SteamSignIn

  setup do
    mock_steam_sign_in(accounts_players(:player).steam_id)
    visit home_path(locale: :en)
    click_steam_sign_in
    assert_selector ".hub"
    find(".hub-menu .menu-item[aria-keyshortcuts='2']").click
    assert_current_path library_path(locale: :en)
    assert_no_selector ".hub"
    seed_library_snapshot_under_the_bridge
    record_rendered_screens
  end

  def seed_library_snapshot_under_the_bridge
    page.execute_script(<<~JS, home_path(locale: :en))
      const view = window.Turbo.session.view
      view.snapshotCache.put(new URL(arguments[0], location.href), view.snapshot.clone())
    JS
  end

  def record_rendered_screens
    page.execute_script(<<~JS)
      window.renderedScreens = []
      document.addEventListener("turbo:render", () => {
        window.renderedScreens.push(document.querySelector(".hub") ? "bridge" : "other")
      })
    JS
  end

  def rendered_screens = page.evaluate_script("window.renderedScreens")

  test "following a link to the bridge shows the bridge without previewing the screen cached under its address" do
    find(".top-bar__home").click
    assert_selector ".hub"
    assert_equal [ "bridge" ], rendered_screens
  end

  test "going back to the bridge through history shows the bridge without restoring the screen cached under its address" do
    page.go_back
    assert_selector ".hub"
    assert_equal [ "bridge" ], rendered_screens
  end
end
