require "test_helper"
require_relative "../support/steam_sign_in"

class NativeSignInsControllerTest < ActionDispatch::IntegrationTest
  include SteamSignIn

  STATE = "s" * 43

  setup { @player = accounts_players(:player) }

  def callback_ticket
    URI.decode_www_form(URI(response.location).query).to_h.fetch("ticket")
  end

  test "a visitor is sent to the sign-in, which brings them back here" do
    get native_sign_in_path(locale: :fr, state: STATE)

    assert_redirected_to sign_in_path(locale: :fr, origin: "/fr/native/sign-in/#{STATE}")
  end

  test "signing in with Steam from the app comes back to the hand-off, not the hub" do
    sign_in(@player, origin: "/fr/native/sign-in/#{STATE}")
    follow_redirect!

    assert_equal "/fr/native/sign-in/#{STATE}", path
    assert_select "form[action='/fr/native/sign-in/#{STATE}'][method=post] button", text: "Revenir à l'appli"
  end

  test "going back to the app hands it a ticket for this player and this state" do
    sign_in(@player)

    post native_sign_in_path(locale: :en, state: STATE)

    assert_response :see_other
    assert response.location.start_with?("gameble://sign-in?ticket=")
    assert_equal @player, NativeSignIn.player_for(callback_ticket, state: STATE)
    assert_nil NativeSignIn.player_for(callback_ticket, state: "t" * 43)
  end

  test "a state that is not the app's format is not routed" do
    get "/en/native/sign-in/short"

    assert_response :not_found
  end
end
