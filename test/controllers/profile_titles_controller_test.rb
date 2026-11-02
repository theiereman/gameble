require "test_helper"
require_relative "../support/catalog_seeds"
require_relative "../support/game_sets"
require_relative "../support/steam_sign_in"

class ProfileTitlesControllerTest < ActionDispatch::IntegrationTest
  include CatalogSeeds
  include GameSets
  include SteamSignIn

  setup do
    @player = accounts_players(:player)
    season, cards = published_cards(5)
    @valve = insert_set(cards, { novice: 1, adept: 3, complete: 5 }, kind: "studio", key: "valve", params: { "studio" => "Valve" }, season:)
    Game::SetTier.insert_all!(%w[novice adept].map { |tier| { player_id: @player.id, set_id: @valve, tier:, reached_by: "trade", reached_at: Time.current } })
  end

  def stored = Game::PlayerState.where(player_id: @player.id).pick(:active_title_kind, :active_title_key, :active_title_rank)

  test "a visitor is sent to sign in" do
    patch personalization_title_path(locale: :en), params: { title: "adept:studio:valve" }

    assert_response :redirect
    assert_nil stored.compact.presence
  end

  test "the page offers the earned titles in one menu grouped by rank with a no title option, the active one selected" do
    Game::ChooseProfileTitle.new.call(player: @player, rank: "adept", kind: "studio", key: "valve").value!
    sign_in(@player)

    get personalization_path(locale: :fr)

    assert_select "section h2#personalization-title-heading", "Titre de profil"
    assert_select "select.title-picker__select[name=title][aria-labelledby=personalization-title-heading]", 1
    assert_equal [ "Aucun titre", "Adepte · Valve", "Novice · Valve" ], css_select(".title-picker__select option").map { it.text.strip }
    assert_equal [ "Adepte", "Novice" ], css_select(".title-picker__select optgroup").map { it["label"] }
    assert_select ".title-picker__select option[selected]", 1
    assert_select ".title-picker__select option[value='adept:studio:valve'][selected]"
    assert_select "[style]", false
  end

  test "a player with no earned title sees how to earn one and only the no title row" do
    Game::SetTier.where(player_id: @player.id).delete_all
    sign_in(@player)

    get personalization_path(locale: :en)

    assert_select ".title-picker__select option", 1
    assert_select ".title-picker__select optgroup", 0
    assert_select ".personalization-section__empty", /Reach a tier of a set/
  end

  test "choosing an earned title stores it and shows the toast on the page" do
    sign_in(@player)

    patch personalization_title_path(locale: :en), params: { title: "novice:studio:valve" }

    assert_redirected_to personalization_path(locale: :en)
    assert_equal %w[studio valve novice], stored
    follow_redirect!
    assert_select ".toast", /Title equipped/
    assert_select "select.title-picker__select[autofocus] option[value='novice:studio:valve'][selected]"
  end

  test "the empty value removes the title with its own toast" do
    Game::ChooseProfileTitle.new.call(player: @player, rank: "adept", kind: "studio", key: "valve").value!
    sign_in(@player)

    patch personalization_title_path(locale: :fr), params: { title: "" }

    assert_equal [ nil, nil, nil ], stored
    follow_redirect!
    assert_select ".toast", /Titre retiré/
  end

  test "a forged title the player has not earned changes nothing" do
    sign_in(@player)

    assert_no_difference -> { Rails.configuration.event_store.read.count } do
      patch personalization_title_path(locale: :en), params: { title: "complete:studio:valve" }
      patch personalization_title_path(locale: :en, format: :json), params: { title: "adept:studio:nobody" }
    end

    assert_response :unprocessable_content
    assert_equal "title_not_earned", response.parsed_body.dig("error", "code")
    assert_nil stored.compact.presence
  end
end
