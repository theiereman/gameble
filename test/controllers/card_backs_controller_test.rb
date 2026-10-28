require "test_helper"
require_relative "../support/steam_sign_in"

class CardBacksControllerTest < ActionDispatch::IntegrationTest
  include SteamSignIn

  setup do
    @player = accounts_players(:player)
    Game::CardBackUnlock.record(@player.id, "set-theme-rpg", Time.current)
  end

  def stored = Game::PlayerState.where(player_id: @player.id).pick(:active_card_back)

  test "a visitor is sent to sign in" do
    patch personalization_back_path(locale: :en), params: { back: "set-theme-rpg" }

    assert_response :redirect
    assert_nil stored
  end

  test "the page shows the active back, the unlocked ones to choose and the locked ones with their condition" do
    sign_in(@player)

    get personalization_path(locale: :fr)

    assert_select "section h2#personalization-back-heading", "Dos de carte"
    assert_select ".back-picker__preview-name", "Standard"
    assert_select ".back-picker__tile--active", 1
    assert_select ".back-picker__tile--locked", Game::CardBacks::KEYS.size - 2
    assert_select ".back-picker__tile button[disabled]", 1
    assert_select ".back-picker__tile form[action$='/personalization/back'] input[name=back][value='set-theme-rpg']"
    assert_select ".back-picker__tile--locked .back-picker__status", /Réunissez la moitié du set/
    assert_select ".back-picker__tile:not(.back-picker__tile--locked):not(.back-picker__tile--active) .back-picker__status", "Choisir"
    assert_select "[style]", false
  end

  test "choosing an unlocked back stores it and shows the toast and the new preview" do
    sign_in(@player)

    patch personalization_back_path(locale: :en), params: { back: "set-theme-rpg" }

    assert_redirected_to personalization_path(locale: :en)
    assert_equal "set-theme-rpg", stored
    follow_redirect!
    assert_select ".toast", /Card back equipped/
    assert_select ".back-picker__preview-name", "RPG"
    assert_select ".back-picker__tile--active .back-picker__name", "RPG"
  end

  test "a forged locked or unknown back changes nothing" do
    sign_in(@player)

    assert_no_difference -> { Rails.configuration.event_store.read.count } do
      patch personalization_back_path(locale: :en, format: :json), params: { back: "set-theme-horror" }
      assert_response :unprocessable_content
      assert_equal "back_locked", response.parsed_body.dig("error", "code")

      patch personalization_back_path(locale: :en, format: :json), params: { back: "not-a-back" }
      assert_response :unprocessable_content
      assert_equal "unknown_back", response.parsed_body.dig("error", "code")
    end

    assert_nil stored
  end

  test "a locked back submitted from the page answers with the alert toast" do
    sign_in(@player)

    patch personalization_back_path(locale: :en), params: { back: "set-theme-horror" }, as: :turbo_stream

    assert_response :unprocessable_content
    assert_includes response.body, "still locked"
    assert_nil stored
  end
end
