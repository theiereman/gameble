require "application_system_test_case"
require_relative "../support/game_packs"
require_relative "../support/steam_sign_in"

# The countdown to the next pack in the top bar's packs chip: away from the
# hub, the chip alone refreshes at zero, without a page visit.
class CountdownTest < ApplicationSystemTestCase
  include GamePacks
  include SteamSignIn

  setup do
    @player = accounts_players(:player)
    mock_steam_sign_in(@player.steam_id)
  end

  COUNTDOWN = ".top-bar .packs-chip__next[data-controller=countdown]".freeze

  test "elsewhere the chip alone refreshes at zero: the count rises without a page visit" do
    create_pack(@player)
    visit home_path(locale: :en)
    click_steam_sign_in
    assert_signed_in

    create_pack(@player, available_at: 5.seconds.from_now)
    visit card_path(locale: :en, slug: "portal")
    page.execute_script("window.refreshes = 0; document.addEventListener('turbo:load', () => window.refreshes++)")
    page.execute_script("document.querySelector('main').testMark = 'kept'")

    assert_selector ".top-bar .packs-chip__count", text: "2", wait: 15
    assert_no_selector COUNTDOWN, visible: :all
    assert_equal 0, page.evaluate_script("window.refreshes")
    assert_equal "kept", page.evaluate_script("document.querySelector('main').testMark"), "the chip should refresh alone, without a page visit"
  end
end
