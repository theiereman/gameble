require "application_system_test_case"
require_relative "../support/catalog_seeds"
require_relative "../support/game_sets"
require_relative "../support/steam_sign_in"

# One set's album: its FILTRES zone and search narrow it under an unchanged
# header, keeping the focus.
class CollectionSetTest < ApplicationSystemTestCase
  include CatalogSeeds
  include GameSets
  include SteamSignIn

  def members(season, key)
    set = Catalog::Set.find_by!(season_id: season.id, key:)
    Catalog::SetMembership.where(set_id: set.id).order(:position, :id).pluck(:card_season_id)
  end

  def sign_in(player)
    mock_steam_sign_in(player.steam_id)
    visit home_path(locale: :en)
    click_steam_sign_in
    assert_signed_in
  end

  def album_titles = all(".set-album__grid .card__title", visible: :all).map { it.text(:all).strip }

  test "the album's FILTRES zone narrows a set of forty cards, keeps the header and the focus, clears back to set order, and the back button still leads back" do
    season, cards = published_cards(40)
    insert_theme(cards, key: "roguelike", season:)
    rate(cards.first(10), Catalog::Rarity::TIERS.key(:rare))
    player = accounts_players(:player)
    hold_all(player, cards.values_at(0, 5, 12, 20, 33))
    titles = Catalog::CardViews.call(cards, locale: :en).values_at(*cards).map(&:title)
    sign_in(player)

    visit library_path(locale: :en)
    find(".set-tiles a.set-tile[href='#{library_set_path(locale: :en, kind: "theme", key: "roguelike")}']").click
    assert_selector ".set-album__grid > li", count: 40, visible: :all
    assert_equal titles, album_titles
    header = find(".set-album__header").text

    find(".filters__summary").click
    find(".filter-chip__text", text: /\AMissing\z/i).click
    assert_selector ".set-album__grid > li", count: 35, visible: :all
    assert_no_selector ".set-album__grid .card:not(.card--not-owned)", visible: :all
    assert_selector "[data-group=state] .filter-chip__box[value=missing]:focus", visible: :all
    assert_selector ".filters__count", text: "1"
    assert_equal header, find(".set-album__header").text
    assert_equal "5", find("progress.set-album__bar")["value"]

    within("[data-group=rarity]") { find(".filter-chip__text", text: /\ARare\z/i).click }
    assert_selector ".set-album__grid > li", count: 8, visible: :all
    assert_equal titles.values_at(1, 2, 3, 4, 6, 7, 8, 9), album_titles
    assert_selector ".filters__count", text: "2"

    find(".filters__clear").click
    assert_selector ".set-album__grid > li", count: 40, visible: :all
    assert_no_selector ".filters__count", visible: true
    assert_equal titles, album_titles
    assert_selector "#set-album-heading:focus"
    go_back
    assert_current_path library_path(locale: :en)
    find(".set-tiles a.set-tile[aria-current=true][href='#{library_set_path(locale: :en, kind: "theme", key: "roguelike")}']").click
    assert_selector "#set-album-heading:focus"
    assert_selector ".set-album__grid > li", count: 40, visible: :all

    field = find("#collection-search")
    field.click
    field.send_keys("seed 3")
    assert_selector ".set-album__grid > li", count: 11, visible: :all
    assert_selector "#collection-search:focus"
    assert_equal header, find(".set-album__header").text

    find(".top-bar__start > a.top-bar__previous", text: /SETS\z/).click
    assert_current_path library_path(locale: :en)
  end
end
