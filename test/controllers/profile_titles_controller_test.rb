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

  test "the Me page's title sheet offers the earned titles grouped by rank after a no title choice, the worn one current" do
    Game::ChooseProfileTitle.new.call(player: @player, rank: "adept", kind: "studio", key: "valve").value!
    sign_in(@player)

    get me_path(locale: :fr)

    assert_select "#me-title-sheet-title", "Titre de profil"
    assert_equal [ "Aucun titre", "Adepte · Valve", "Novice · Valve" ], css_select("#me-title-sheet button.filter-chip").map { it.text.strip }
    assert_equal [ "Adepte", "Novice" ], css_select("#me-title-sheet .me-sheet__heading").map(&:text)
    assert_select "#me-title-sheet button[aria-current=true]", 1
    assert_select "#me-title-sheet button[type=button][aria-current=true]", "Adepte · Valve"
    assert_select "#me-title-sheet input[name=title][value='adept:studio:valve']", false
    assert_select "[style]", false
  end

  test "a player with no earned title sees how to earn one and only the no title choice" do
    Game::SetTier.where(player_id: @player.id).delete_all
    sign_in(@player)

    get me_path(locale: :en)

    assert_select "#me-title-sheet button.filter-chip", 1
    assert_select "#me-title-sheet .me-sheet__heading", 0
    assert_select "#me-title-sheet .me-sheet__note", /Reach a tier of a set/
  end

  test "choosing an earned title stores it and shows the toast on the Me page, the title in the band" do
    sign_in(@player)

    patch personalization_title_path(locale: :en), params: { title: "novice:studio:valve" }

    assert_redirected_to me_path(locale: :en)
    assert_equal %w[studio valve novice], stored
    follow_redirect!
    assert_select ".toast", /Title equipped/
    assert_select ".profile-band a.me-title-opener[autofocus] .profile-title", "Novice · Valve"
    assert_select "#me-title-sheet button[type=button][aria-current=true]", "Novice · Valve"
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
