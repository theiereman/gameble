require "test_helper"
require_relative "../support/game_packs"
require_relative "../support/steam_sign_in"

class BankCounterTest < ActionDispatch::IntegrationTest
  include GamePacks
  include SteamSignIn

  test "the hub header carries the G home button and a merged counter whose detail links to the booster" do
    player = accounts_players(:player)
    create_pack(player)
    create_pack(player, available_at: 10.minutes.from_now)
    sign_in(player)

    get home_path(locale: :en)

    assert_select "header.top-bar--top-level span.top-bar__g-home"
    assert_select "a.top-bar__g-home", false
    assert_select ".bank-counter .bank-counter__item", 2
    assert_select ".bank-counter #bank-detail a[href='/en/booster']", "Open a capsule"
    assert_select ".bank-counter #bank-detail [data-controller=countdown][data-countdown-refresh-value=false]"
  end

  test "a drill-down screen keeps the two chips and no G home button" do
    player = accounts_players(:player)
    sign_in(player)

    get settings_path(locale: :en)

    assert_select "header.top-bar--top-level", false
    assert_select "a.top-bar__g-home", false
  end
end
