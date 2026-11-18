require "application_system_test_case"
require_relative "../support/game_packs"
require_relative "../support/steam_sign_in"

class BankCounterSystemTest < ApplicationSystemTestCase
  include GamePacks
  include SteamSignIn

  PHONE = [ 390, 844 ].freeze

  test "the Capsule tab's badge follows a change of the bank" do
    player = accounts_players(:player)
    create_pack(player)
    mock_steam_sign_in(player.steam_id)
    visit home_path(locale: :en)
    click_steam_sign_in
    assert_signed_in
    resize_to(*PHONE)

    page.execute_script(<<~JS)
      window.dispatchEvent(new CustomEvent("gameble:bank-changed", { detail: { available: 7, special: 3 } }))
    JS

    assert_selector ".tab-bar__capsules .tab-bar__badge", text: "10"
    assert_selector ".tab-bar__capsules .visually-hidden", text: "10 capsules ready to open", visible: :all

    page.execute_script(<<~JS)
      window.dispatchEvent(new CustomEvent("gameble:bank-changed", { detail: { available: 0, special: 0 } }))
    JS

    assert_no_selector ".tab-bar__capsules"
  end

  test "the Capsule tab's icon sits level with the other tabs' while the badge shows" do
    player = accounts_players(:player)
    create_pack(player)
    mock_steam_sign_in(player.steam_id)
    visit home_path(locale: :en)
    click_steam_sign_in
    assert_signed_in
    resize_to(*PHONE)

    assert_selector ".tab-bar__capsules .tab-bar__badge"
    tops = page.evaluate_script("Array.from(document.querySelectorAll('.tab-bar__icon'), (icon) => icon.getBoundingClientRect().top)")

    assert_equal 1, tops.uniq.size
  end
end
