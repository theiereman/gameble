require "application_system_test_case"
require_relative "../support/catalog_seeds"
require_relative "../support/game_sets"
require_relative "../support/steam_sign_in"

# A player's own set, from the collection: the picker's search and checks,
# the album it opens, its rename and its deletion; MES SETS gives way to a
# set search and never shows on a public profile.
class CustomSetsTest < ApplicationSystemTestCase
  include CatalogSeeds
  include GameSets
  include SteamSignIn

  setup do
    @player = accounts_players(:player)
    @season, @cards = published_cards(5)
  end

  def sign_in(player)
    mock_steam_sign_in(player.steam_id)
    visit home_path(locale: :en)
    click_steam_sign_in
    assert_signed_in
  end

  def title(index) = Catalog::CardText.find_by!(card_id: Catalog::CardSeason.find(@cards[index]).card_id, locale: "en").title

  test "a player names a set, searches and checks three games, saves, and lands on its album, then finds it in MES SETS" do
    hold_all(@player, [ @cards[1] ])
    sign_in(@player)
    visit library_path(locale: :en)

    within("section.custom-sets") do
      assert_text "Visible to you only · 0 / 10"
      click_on "+ New set"
    end
    assert_selector "h1", text: "NEW SET"
    fill_in "Set name", with: "Mes favoris"
    fill_in "Find a game", with: "Seed"
    click_on "Search"
    assert_field "Set name", with: "Mes favoris"
    [ 0, 1, 2 ].each { check title(it) }
    click_on "Save"

    assert_selector "h1#set-album-heading", text: "MES FAVORIS"
    assert_selector ".set-album__count", text: "1/3"
    assert_selector ".set-album__grid .card.card--not-owned", count: 2
    assert_selector ".set-album__grid .card:not(.card--not-owned)", count: 1
    assert_no_selector ".set-album__ticks"

    visit library_path(locale: :en)
    within("section.custom-sets") do
      assert_text "Visible to you only · 1 / 10"
      assert_link class: "custom-sets__link", text: /Mes favoris/
    end
  end

  test "the author renames the set through Edit and deletes it through Delete" do
    custom_set = Game::CreateCustomSet.new.call(player: @player, name: "Mes favoris", card_ids: Catalog::CardSeason.where(id: @cards.first(3)).pluck(:card_id)).value!
    sign_in(@player)
    visit custom_set_path(locale: :en, token: custom_set.token)

    click_on "Edit"
    fill_in "Set name", with: "Jeux du soir"
    click_on "Save"
    assert_selector "h1#set-album-heading", text: "JEUX DU SOIR"
    visit library_path(locale: :en)
    assert_selector ".custom-sets__name", text: "Jeux du soir"

    click_on "Jeux du soir"
    accept_confirm("Delete “Jeux du soir”?") { click_on "Delete" }

    assert_selector "#toasts .toast", text: /Set deleted/i
    assert_selector "#toasts .toast", text: "“Jeux du soir” is no longer one of your sets."
    assert_current_path library_path(locale: :en)
    assert_no_selector ".custom-sets__link"
    assert_text "Visible to you only · 0 / 10"
  end

  test "a typed set search hides MES SETS as it hides EN COURS; a public profile's collection has no MES SETS" do
    insert_theme(@cards, key: "roguelike", season: @season)
    Game::CreateCustomSet.new.call(player: @player, name: "Mes favoris", card_ids: Catalog::CardSeason.where(id: @cards.first(3)).pluck(:card_id)).value!
    sign_in(@player)
    visit library_path(locale: :en)
    assert_selector "section.custom-sets", visible: true

    fill_in "set-search-field", with: "rogue"
    assert_selector ".set-results"
    assert_no_selector "section.custom-sets", visible: true

    fill_in "set-search-field", with: ""
    assert_selector "section.custom-sets", visible: true

    visit brother_collection_path(locale: :en, token: @player.token)
    assert_selector ".collection .collection-grid"
    assert_no_selector ".custom-sets"
    assert_no_text "Mes favoris"
  end
end
