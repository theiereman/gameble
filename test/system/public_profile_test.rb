require "application_system_test_case"
require_relative "../support/catalog_seeds"
require_relative "../support/steam_api_stubs"

# A player's public profile (CAP-8, story 4.4): a player signs in, their
# Steam persona name is stored, and they find the link to their profile in
# the library; a visitor opens that link and sees the owner's name, started
# sets, counts and, in a tome, the owner's cards.
class PublicProfileTest < ApplicationSystemTestCase
  include CatalogSeeds
  include SteamApiStubs

  setup do
    stub_steam_api
    @season = publish_sets_draft
    @player = accounts_players(:player)
    stub_player_summary(@player.steam_id, "Gabe the Brave")
    publisher = Catalog::Set.find_by!(season_id: @season.id, key: "p")
    @owned = Catalog::SetMembership.where(set_id: publisher.id).order(:position, :id).pluck(:card_season_id)
    @owned.each_with_index { |id, index| Game::Holding.create!(player_id: @player.id, card_season_id: id, quantity: index.zero? ? 2 : 1) }
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:steam] = OmniAuth::AuthHash.new(provider: "steam", uid: "https://steamcommunity.com/openid/id/#{@player.steam_id}")
  end

  teardown do
    OmniAuth.config.mock_auth.delete(:steam)
    OmniAuth.config.test_mode = false
    unstub_steam_api
  end

  test "a player finds their public profile in the library; a visitor reads it" do
    visit home_path(locale: :en)
    click_on "Enlist through Steam"
    assert_button "Stand down"
    assert_equal "Gabe the Brave", @player.reload.persona_name

    click_on "Library"
    click_on "Your public profile"

    assert_current_path brother_path(locale: :en, token: @player.token)
    assert_title "Gabe the Brave"
    assert_selector "h1", text: "Gabe the Brave"
    assert_selector ".profile__counts li", text: "5 cards collected"
    assert_selector ".library__tab[aria-current=page]", text: "Started"
    assert_selector ".shelf .tome", text: "P"
    assert_selector ".shelf .tome .tome__complete", text: "Complete"
    take_screenshot

    click_on "Stand down"
    assert_button "Enlist through Steam"
    visit brother_path(locale: :en, token: @player.token)

    assert_selector "h1", text: "Gabe the Brave"
    click_on "Publishers"
    assert_selector ".library__tab[aria-current=page]", text: "Publishers"
    find(".shelf a.tome", text: "P").click

    assert_selector ".open-tome__heading", text: "P"
    assert_selector ".open-tome__progress", text: "5 / 5"
    assert_selector ".open-tome__slots .card--face", count: 5
    assert_selector ".open-tome__copies", count: 1, text: "×2"
    assert_selector ".library__aside .tome[aria-current=page]", text: "P"
    take_screenshot

    click_on "The library of Gabe the Brave"
    assert_current_path brother_path(locale: :en, token: @player.token)
    assert_no_selector "a.library__profile"
  end

  test "a visitor finds no profile behind an unknown link" do
    visit brother_path(locale: :fr, token: "A" * 24)

    assert_selector "h1", text: "Profil indisponible"
    assert_no_selector ".shelf"
  end
end
