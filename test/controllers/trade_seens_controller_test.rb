require "test_helper"
require_relative "../support/counting_rate_limit"
require_relative "../support/steam_sign_in"

# POST /:locale/trades/:token/seen: the board posts it when it shows an answer
# the player has not seen; 204 and no body, 404 for a trade that is not theirs.
class TradeSeensControllerTest < ActionDispatch::IntegrationTest
  include CountingRateLimit
  include SteamSignIn

  setup do
    @hugo = accounts_players(:player)
    @max = accounts_players(:moderator)
    @eve = accounts_players(:administrator)
    @trade = trade_between(@hugo, @max)
  end

  def trade_between(proposer, recipient)
    low, high = [ proposer.id, recipient.id ].minmax
    Game::Trade.create!(low_player_id: low, high_player_id: high, proposer_id: proposer.id, recipient_id: recipient.id,
      status: "declined", proposed_at: 2.hours.ago, expires_at: 1.day.from_now, closed_at: 1.hour.ago)
  end

  def mark(token = @trade.token) = post(trade_seen_path(token:, locale: :en))

  test "the proposer's marker is written: 204, no body, no id" do
    sign_in(@hugo)

    assert_difference -> { Game::TradeView.count }, 1 do
      mark
    end

    assert_response :no_content
    assert_empty response.body
    assert_empty Game::TradeUpdates.call(@hugo)
  end

  test "posting twice succeeds twice with one row" do
    sign_in(@hugo)

    2.times { mark and assert_response :no_content }

    assert_equal 1, Game::TradeView.count
  end

  test "another pair's trade and an unknown token are 404, nothing written" do
    sign_in(@eve)

    assert_no_difference -> { Game::TradeView.count } do
      mark
      assert_response :not_found
      mark("A" * 24)
      assert_response :not_found
    end
  end

  test "a visitor writes nothing" do
    assert_no_difference -> { Game::TradeView.count } do
      mark
    end

    assert_not response.successful?
  end

  test "sixty marks a minute are answered; the sixty-first is throttled" do
    sign_in(@hugo)

    with_counting_rate_limit(TradeSeensController) do
      60.times { mark and assert_response :no_content }
      mark

      assert_response :too_many_requests
      assert_equal "60", response.headers["Retry-After"]
    end
  end
end
