require "test_helper"
require_relative "../support/game_packs"
require_relative "../support/steam_sign_in"

class BankCounterTest < ActionDispatch::IntegrationTest
  include GamePacks
  include SteamSignIn

  test "the hub header carries the wordmark home button and a merged counter whose detail links to the booster" do
    player = accounts_players(:player)
    create_pack(player)
    create_pack(player, available_at: 10.minutes.from_now)
    sign_in(player)

    get home_path(locale: :en)

    assert_select "header.top-bar--top-level span.top-bar__phone-home"
    assert_select "a.top-bar__phone-home", false
    assert_select ".bank-counter .bank-counter__item", 2
    assert_select ".bank-counter #bank-detail a[href='/en/booster']", "Open a capsule"
    assert_select ".bank-counter #bank-detail [data-controller=countdown][data-countdown-refresh-value=false]"
  end

  test "a drill-down screen keeps the two chips and no wordmark home button" do
    player = accounts_players(:player)
    sign_in(player)

    get settings_path(locale: :en)

    assert_select "header.top-bar--top-level", false
    assert_select "a.top-bar__phone-home", false
  end

  test "the trades and market screens carry the top-level header" do
    sign_in(accounts_players(:player))

    [ trades_path(locale: :en), market_path(locale: :en) ].each do |path|
      get path
      assert_select "header.top-bar--top-level", 1, path
    end
  end

  test "a trade sub-screen that offers a way back drops the top-level header" do
    player = accounts_players(:player)
    sign_in(player)

    get new_trade_path(locale: :en)

    assert_select "header.top-bar--top-level", false
  end

  test "a visitor gets no top-level header" do
    get home_path(locale: :en)

    assert_select "header.top-bar--top-level", false
  end
end
