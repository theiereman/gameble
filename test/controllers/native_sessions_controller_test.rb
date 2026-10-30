require "test_helper"

class NativeSessionsControllerTest < ActionDispatch::IntegrationTest
  STATE = "s" * 43

  setup do
    @player = accounts_players(:player)
    ActionController::Base.allow_forgery_protection = true
  end

  teardown { ActionController::Base.allow_forgery_protection = false }

  def ticket(player = @player, state: STATE) = NativeSignIn.ticket(player, state:)

  def redeem(ticket, state: STATE) = post(native_session_path(locale: :fr), params: { ticket:, state: })

  test "the app trades a valid ticket for the player's session, without an authenticity token" do
    redeem(ticket)

    assert_response :no_content
    assert_equal @player.id, session[:player_id]
  end

  test "a ticket with another state, a forged or expired one, or a banned player's opens nothing" do
    redeem(ticket, state: "t" * 43)
    assert_response :unauthorized

    redeem("#{ticket}x")
    assert_response :unauthorized

    expired = ticket
    travel(NativeSignIn::LIFETIME + 1.second) { redeem(expired) }
    assert_response :unauthorized

    redeem(ticket(accounts_players(:banned)))
    assert_response :unauthorized
    assert_nil session[:player_id]
  end
end
