require "application_system_test_case"
require_relative "../support/catalog_seeds"
require_relative "../support/game_sets"
require_relative "../support/steam_sign_in"

# One set's album: its missing cards are the grid's faces not owned, at a
# medium card's size, a long title whole in their accessible name; a large
# set's album comes sixty cards to a page, and draws its art only near the
# viewport; its FILTRES zone and search narrow it under an unchanged header.
# Between 720 and 1179px the grid's sets are a strip above it.
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

  def assert_no_sideways_scroll
    assert page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth"), "the page should not scroll sideways"
  end

  test "a missing card is the grid's face not owned, a medium card's size, its long title whole in its accessible name" do
    season = publish_sets_draft
    long = "The Long Chronicles of the Amethyst Archive and the Keys Its Keepers Lost at Sea"
    Catalog::CardText.where(card_id: Catalog::CardSeason.find(members(season, "horror").first).card_id, locale: "en").update_all(title: long)
    sign_in(accounts_players(:player))

    visit library_set_path(locale: :en, kind: "theme", key: "horror")

    assert_selector ".set-album__grid a.card-link .card.card--grid.card--not-owned", count: 16
    link = find(".set-album__grid a.card-link", match: :first)
    assert_equal [ 160, 240 ], link.evaluate_script("[ this.getBoundingClientRect().width, this.getBoundingClientRect().height ]")
    assert link["aria-label"].start_with?("#{long}, "), "the accessible name should hold the whole title"
    assert link["aria-label"].end_with?(", not owned"), "the accessible name should say the card is not owned"
    assert_equal long, link.find(".card__title").text(:all).strip
    assert_selector ".card--not-owned .card__lock svg", count: 16
    assert_no_selector ".card--not-owned .card__effects, .card--not-owned[data-controller~=tilt]"
  end

  def album_titles = all(".set-album__grid .card__title", visible: :all).map { it.text(:all).strip }

  test "the album's FILTRES zone narrows a set of forty cards, keeps the header and the focus, clears back to set order, and the back button still leads back" do
    season, cards = published_cards(40)
    insert_theme(cards, key: "roguelike", season:)
    Catalog::CardSeason.where(id: cards.first(10)).update_all(rarity: Catalog::Rarity::TIERS.key(:rare))
    player = accounts_players(:player)
    hold_all(player, cards.values_at(0, 5, 12, 20, 33))
    titles = Catalog::CardViews.call(cards, locale: :en).values_at(*cards).map(&:title)
    sign_in(player)

    visit library_path(locale: :en)
    find(".set-entry__list .set-row", text: /\AROGUELIKE\b/).click
    assert_selector ".set-album__grid > li", count: 40, visible: :all
    assert_equal titles, album_titles
    header = find(".set-album__header").text

    find(".filters__summary").click
    find(".filter-chip__text", text: /\AMissing\z/i).click
    assert_selector ".set-album__grid > li", count: 35, visible: :all
    assert_no_selector ".set-album__grid .card:not(.card--not-owned)", visible: :all
    assert_equal "Missing", page.evaluate_script("document.activeElement.parentElement.textContent.trim()")
    assert_selector ".filters__count", text: "1"
    assert_equal header, find(".set-album__header").text
    assert_equal "5", find("progress.set-album__bar")["value"]

    within("[data-group=rarity]") { find(".filter-chip__text", text: /\ARare\z/i).click }
    assert_selector ".set-album__grid > li", count: 8, visible: :all
    assert_equal titles.values_at(1, 2, 3, 4, 6, 7, 8, 9), album_titles
    assert_selector ".filters__count", text: "2"
    take_screenshot

    find(".filters__clear").click
    assert_selector ".set-album__grid > li", count: 40, visible: :all
    assert_no_selector ".filters__count", visible: true
    assert_equal titles, album_titles
    assert_equal "set-album-heading", page.evaluate_script("document.activeElement.id")

    field = find("#collection-search")
    field.click
    field.send_keys("seed 3")
    assert_selector ".set-album__grid > li", count: 11, visible: :all
    assert_equal "collection-search", page.evaluate_script("document.activeElement.id")
    assert_equal header, find(".set-album__header").text
    assert_no_sideways_scroll

    find(".top-bar__start > a.top-bar__previous", text: /SETS\z/).click
    assert_current_path library_path(locale: :en)
  end

  test "between 720 and 1179px the grid stands alone: no set column, the RAPPORT hidden" do
    publish_sets_draft
    page.driver.browser.manage.window.resize_to(900, 900)

    visit library_cards_path(locale: :en)

    assert_no_selector ".collection__aside, .report--panel, .report--fold", visible: true
    assert_selector "[data-group=sets]", visible: :all
    assert_operator page.evaluate_script("document.querySelector('.filters').getBoundingClientRect().top"), :<,
      page.evaluate_script("document.querySelector('.collection-grid').getBoundingClientRect().top")
    assert_no_sideways_scroll
    take_screenshot
  end
end
