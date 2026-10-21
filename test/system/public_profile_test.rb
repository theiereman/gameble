require "application_system_test_case"
require_relative "../support/catalog_seeds"
require_relative "../support/steam_api_stubs"
require_relative "../support/steam_sign_in"

# A player's public profile: a player signs in, their
# Steam persona name is stored, and they find the link to their profile in
# the library; a visitor opens that link and sees the owner's avatar and name,
# key numbers, started sets and, in a set, the owner's cards (the collection's
# components, read-only).
class PublicProfileTest < ApplicationSystemTestCase
  include CatalogSeeds
  include SteamApiStubs
  include SteamSignIn

  setup do
    stub_steam_api
    @season = publish_sets_draft
    @player = accounts_players(:player)
    stub_player_summary(@player.steam_id, "Gabe the Brave")
    pirates = Catalog::Set.find_by!(season_id: @season.id, key: "pirates")
    @owned = Catalog::SetMembership.where(set_id: pirates.id).order(:position, :id).pluck(:card_season_id)
    @owned.each_with_index { |id, index| Game::Holding.create!(player_id: @player.id, card_season_id: id, quantity: index.zero? ? 2 : 1) }
    mock_steam_sign_in(@player.steam_id)
  end

  teardown do
    unstub_steam_api
  end

  test "a player finds their public profile in the player menu; a visitor reads it" do
    visit home_path(locale: :en)
    click_steam_sign_in
    assert_signed_in
    assert_equal "Gabe the Brave", @player.reload.persona_name

    within(".hub-menu") { click_on "Collection" }
    assert_current_path library_path(locale: :en)
    find(".player-chip__button").click
    within("#player-menu") { click_on "My public profile" }

    assert_current_path brother_path(locale: :en, token: @player.token)
    assert_title "Gabe the Brave"
    assert_selector "h1", text: "Gabe the Brave"
    assert_selector ".profile-band__avatar"
    assert_selector ".profile-band__keys .profile-figure", text: /\Acards\s*8\//i
    assert_selector ".profile-sets .set-row", text: %r{\AHorror\s+Theme\s+.*8/16}im
    take_screenshot

    sign_out
    assert_signed_out
    visit brother_set_path(locale: :en, token: @player.token, kind: "theme", key: "pirates")

    assert_selector "h1", text: /\APirates · Gabe the Brave\z/i
    assert_selector ".set-album__count", text: "8/8"
    assert_selector ".set-album__stamp", text: /\Acomplete\z/i
    assert_selector ".set-album__grid .card.card--grid", count: 8
    assert_selector ".collection-slot__copies", text: "x2", count: 1
    assert_no_selector ".collection-slot__new"
    take_screenshot
  end

  test "a visitor finds no profile behind an unknown link" do
    visit brother_path(locale: :fr, token: "A" * 24)

    assert_selector "h1", text: /\AProfil indisponible\z/i
    assert_no_selector ".collection-sets"
  end
end
