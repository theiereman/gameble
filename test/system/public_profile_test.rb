require "application_system_test_case"
require_relative "../support/catalog_seeds"
require_relative "../support/steam_api_stubs"

# A player's public profile: a player signs in, their
# Steam persona name is stored, and they find the link to their profile in
# the library; a visitor opens that link and sees the owner's avatar and name,
# counts, started sets and, in a set, the owner's cards (the collection's
# components, read-only).
class PublicProfileTest < ApplicationSystemTestCase
  include CatalogSeeds
  include SteamApiStubs

  setup do
    stub_steam_api
    @season = publish_sets_draft
    @player = accounts_players(:player)
    stub_player_summary(@player.steam_id, "Gabe the Brave")
    pirates = Catalog::Set.find_by!(season_id: @season.id, key: "pirates")
    @owned = Catalog::SetMembership.where(set_id: pirates.id).order(:position, :id).pluck(:card_season_id)
    @owned.each_with_index { |id, index| Game::Holding.create!(player_id: @player.id, card_season_id: id, quantity: index.zero? ? 2 : 1) }
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:steam] = OmniAuth::AuthHash.new(provider: "steam", uid: "https://steamcommunity.com/openid/id/#{@player.steam_id}")
  end

  teardown do
    OmniAuth.config.mock_auth.delete(:steam)
    OmniAuth.config.test_mode = false
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
    assert_selector ".profile-summary__avatar"
    assert_selector ".profile-summary__counts li", text: /8 cards collected/i
    assert_selector ".collection-kind[aria-current=true]", text: /\AStarted\z/i
    assert_selector ".set-row", text: %r{\AHorror\s*8/16}i
    assert_selector ".set-row .set-row__count--complete", text: "8/8"
    take_screenshot

    sign_out
    assert_signed_out
    visit brother_path(locale: :en, token: @player.token)

    assert_selector "h1", text: "Gabe the Brave"
    click_on "Themes", match: :first
    assert_selector ".collection-kind[aria-current=true]", text: /\AThemes\z/i
    find(".set-row", text: /\APirates\b/i).click

    assert_selector ".profile-set__heading", text: "Pirates"
    assert_selector ".profile-set__progress", text: "8 / 8"
    assert_selector ".collection-grid .card.card--m", count: 8
    assert_selector ".collection-slot__copies", count: 8
    assert_selector ".collection-slot__copies", text: "x2", count: 1
    assert_selector ".collection__aside .set-row[aria-current=page]", text: /\APirates/i
    assert_no_selector ".shelf, .tome, .library"
    take_screenshot

    click_on "The collection of Gabe the Brave"
    assert_current_path brother_path(locale: :en, token: @player.token, kind: "theme", page: 1)
    assert_no_selector "a.library__profile"
  end

  test "a visitor finds no profile behind an unknown link" do
    visit brother_path(locale: :fr, token: "A" * 24)

    assert_selector "h1", text: "Profil indisponible"
    assert_no_selector ".collection-sets"
  end
end
