require "test_helper"
require_relative "../support/game_packs"
require_relative "../support/steam_sign_in"

class PacksChipsControllerTest < ActionDispatch::IntegrationTest
  include GamePacks
  include SteamSignIn

  setup do
    @player = accounts_players(:player)
  end

  CHIP = "turbo-stream[action=replace][target=packs-chip] template".freeze

  def get_chip(locale: :en)
    get packs_chip_path(locale:), as: :turbo_stream
    assert_response :success
    assert_equal Mime[:turbo_stream], response.media_type
  end

  test "a player's refresh answers the chip alone with the new count and countdown, writing nothing" do
    now = Time.utc(2026, 10, 2, 14, 22)
    travel_to(now) do
      create_pack(@player, available_at: now)
      create_pack(@player, available_at: now + 10.minutes)
    end
    sign_in(@player)

    travel_to(now) do
      assert_no_difference -> { Game::Pack.count } do
        get_chip
      end
    end

    assert_select "#{CHIP} a#packs-chip .packs-chip__count", "1"
    assert_select "#{CHIP} .packs-chip__next [data-countdown-target=clock]", "10:00"
    assert_select "#{CHIP} .packs-chip__next .visually-hidden", "Next capsule: 2026-10-02 14:32 UTC"

    refresh = css_select("#{CHIP} .packs-chip__next[data-controller=countdown]").sole
    assert_equal "600", refresh["data-countdown-seconds-value"]
    assert_equal "false", refresh["data-countdown-refresh-value"]
    assert_equal "/en/packs-chip", refresh["data-countdown-refresh-url-value"]
  end

  test "a full reserve answers the full chip, with no countdown" do
    sign_in(@player)
    10.times { create_pack(@player) }

    get_chip

    assert_select "#{CHIP} .packs-chip__count", "10"
    assert_select "#{CHIP} .packs-chip__next--full", "Reserve full"
    assert_select "#{CHIP} [data-controller=countdown]", false
  end

  test "the chip reads in the request's locale, and follows it on the next refresh" do
    now = Time.utc(2026, 10, 2, 9, 0)
    travel_to(now) { create_pack(@player, available_at: now + 5.minutes) }
    sign_in(@player)

    travel_to(now) do
      get_chip(locale: :fr)

      assert_select "#{CHIP} .packs-chip__next [aria-hidden=true]", text: /\+1 dans\s+05:00/
      assert_select "#{CHIP} .packs-chip__next .visually-hidden", "Prochaine capsule : 2026-10-02 09:05 UTC"
      assert_equal "/fr/packs-chip", css_select("#{CHIP} .packs-chip__next[data-controller=countdown]").sole["data-countdown-refresh-url-value"]
    end
  end

  test "a visitor is sent to the landing" do
    get packs_chip_path(locale: :en)

    assert_redirected_to home_path(locale: :en)
    assert_nil flash[:alert]
  end
end
