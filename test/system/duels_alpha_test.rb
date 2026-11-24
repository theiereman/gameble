require "application_system_test_case"
require_relative "../support/steam_sign_in"
require_relative "../support/live_duels"

# Duels are open to every player as an alpha: the DUELS tab and menu 04 carry the ALPHA tag, the Duels banner says the
# games are analysed, and a friend's public profile shows no duel figure.
class DuelsAlphaTest < ApplicationSystemTestCase
  include SteamSignIn
  include LiveDuels

  PHONE = [ 390, 844 ].freeze

  setup do
    @player = accounts_players(:player)
    @friend = accounts_players(:moderator)
    befriend(@player, @friend)
  end

  teardown { resize_to(*SCREEN_SIZE) }

  def sign_in(player)
    sign_in_browser(player.steam_id)
  end

  test "the DUELS tab and menu 04 show ALPHA, the banner says the games are analysed, a friend's profile has no duel figure" do
    sign_in(@player)

    within(".hub-menu a.menu-item[href='/en/duels']") { assert_selector ".alpha-tag", text: "ALPHA" }

    resize_to(*PHONE)
    within(".tab-bar a.tab-bar__tab[href='/en/duels']") do
      assert_selector ".tab-bar__label", exact_text: "DUELS"
      assert_selector ".alpha-tag", text: "ALPHA"
    end

    find(".tab-bar a.tab-bar__tab[href='/en/duels']").click
    assert_selector ".alpha-banner__warning", text: /Your games are analysed to balance the rules\.\z/

    visit brother_path(locale: :en, token: @friend.token)
    assert_selector ".profile-figure", text: /Capsules opened/i
    assert_no_selector ".profile-figure", text: /Duel/i
  end
end
