require "application_system_test_case"
require_relative "../support/steam_sign_in"

# A friend with his page open is on the other's Duels screen under EN LIGNE and on her friends page with DÉFIER EN DUEL;
# once his lease lapses and she reloads, he is on neither.
class DuelReachabilityTest < ApplicationSystemTestCase
  include SteamSignIn

  setup do
    @lea = accounts_players(:player)
    @hugo = accounts_players(:moderator)
    @lea.update!(persona_name: "Léa")
    @hugo.update!(persona_name: "Hugo")
    low, high = [ @lea.id, @hugo.id ].minmax
    Game::Friendship.create!(low_player_id: low, high_player_id: high)
  end

  teardown { travel_back }

  def sign_in(player)
    mock_steam_sign_in(player.steam_id)
    visit home_path(locale: :en)
    click_steam_sign_in
    assert_signed_in
  end

  test "Hugo is reachable while his page is open and no longer once his lease lapses" do
    using_session(:hugo) do
      sign_in @hugo
      visit duels_path(locale: :en)
      assert_selector "turbo-cable-stream-source[connected]", visible: :all
    end

    using_session(:lea) do
      sign_in @lea
      visit duels_path(locale: :en)
      assert_selector "#duel-online-heading", text: "ONLINE · 1"
      assert_selector ".duel-online__row", text: "Hugo"
      assert_selector ".duel-online__row a.button", text: "CHALLENGE"

      visit friends_path(locale: :en)
      assert_selector ".friends__friend a.button", text: "CHALLENGE TO A DUEL"

      using_session(:hugo) { visit "about:blank" }
      travel 5.minutes
      visit duels_path(locale: :en)
      assert_selector "#duel-online-heading", text: "ONLINE · 0"
      assert_no_selector ".duel-online__row"

      visit friends_path(locale: :en)
      assert_selector ".friends__friend", text: "Hugo"
      assert_no_selector ".friends__friend a.button", text: "CHALLENGE TO A DUEL"
    end
  end
end
