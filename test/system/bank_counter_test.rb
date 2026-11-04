require "application_system_test_case"
require_relative "../support/game_packs"
require_relative "../support/steam_sign_in"

class BankCounterSystemTest < ApplicationSystemTestCase
  include GamePacks
  include SteamSignIn

  PHONE = [ 390, 844 ].freeze

  test "the merged counter and its detail follow a change of the bank" do
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

    assert_selector ".bank-counter__item:not(.bank-counter__item--special) .bank-counter__count", text: "7"
    assert_selector ".bank-counter__item--special .bank-counter__count", text: "3"
    find(".bank-counter__button").click
    assert_selector "#bank-detail .bank-detail__row:first-child .bank-counter__count", text: "7"
    assert_selector "#bank-detail .bank-detail__row:last-child .bank-counter__count", text: "3"
  end
end
