require "test_helper"
require_relative "../support/steam_sign_in"
require_relative "../support/counting_rate_limit"
require_relative "../support/decks"

# Filling a deck's gaps from the editor: the owner alone, a JSON answer naming each filled slot by its card's ref with
# the deck's new coverage, a refusal by its code, and the sixty changes a minute the deck's other saves count too.
class DeckFillsControllerTest < ActionDispatch::IntegrationTest
  include SteamSignIn
  include CountingRateLimit
  include Decks

  setup do
    @player = accounts_players(:player)
    @deck = Game::CreateDeck.new.call(player: @player).value!
  end

  def json = { as: :json }

  test "the fill answers each filled slot with its card's ref, the count and the coverage" do
    popular, obscure = ranked_cards(@player, 2)
    set_percentiles(popular, popularity: 99)
    set_percentiles(obscure, popularity: 2)
    sign_in(@player)

    post deck_fill_path(locale: :en, token: @deck.token), **json

    assert_response :success
    body = response.parsed_body
    assert_equal [ { "slot" => 1, "ref" => ref_of(popular) }, { "slot" => 2, "ref" => ref_of(obscure) } ], body["slots"]
    assert_equal 2, body["count"]
    assert_equal [ { "call" => "popularity-high", "best" => 99, "gap" => false }, { "call" => "popularity-low", "best" => 98, "gap" => false } ],
      body["coverage"].first(2)
    assert_no_match(/"\w*id"\s*:\s*\d/, response.body)
  end

  test "a full deck answers no slot" do
    ranked_cards(@player, 12).each { Game::AddCardToDeck.new.call(player: @player, token: @deck.token, card_season_id: it).value! }
    sign_in(@player)

    post deck_fill_path(locale: :fr, token: @deck.token), **json

    assert_equal [ [], 12 ], response.parsed_body.values_at("slots", "count")
  end

  test "a visitor is refused, another player's deck is forbidden, and an unknown token is not found" do
    post deck_fill_path(locale: :en, token: @deck.token), **json
    assert_response :unauthorized

    sign_in(accounts_players(:moderator))
    post deck_fill_path(locale: :en, token: @deck.token), **json
    assert_response :forbidden

    post deck_fill_path(locale: :en, token: "1" * 24), **json
    assert_response :unprocessable_content
    assert_equal({ "error" => { "code" => "deck_not_found", "message" => "This deck cannot be found." } }, response.parsed_body)
    assert_equal 0, Game::DeckCard.count
  end

  test "fills share the deck changes' sixty a minute" do
    card = ranked_cards(@player, 1).sole
    sign_in(@player)

    with_counting_rate_limit(DeckCardsController) do
      with_counting_rate_limit(DeckFillsController) do
        30.times do
          post deck_cards_path(locale: :en, token: @deck.token), params: { ref: ref_of(card) }, **json
          delete deck_cards_path(locale: :en, token: @deck.token), params: { ref: ref_of(card) }, **json
        end
        assert_response :success

        post deck_fill_path(locale: :en, token: @deck.token), **json
        assert_response :too_many_requests
        assert_equal "throttled", response.parsed_body.dig("error", "code")
        assert_equal 0, Game::DeckCard.count
      end
    end
  end
end
