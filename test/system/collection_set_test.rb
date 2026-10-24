require "application_system_test_case"
require_relative "../support/catalog_seeds"
require_relative "../support/steam_sign_in"

# One set's album: its missing cards are the grid's faces not owned, at a
# medium card's size, a long title whole in their accessible name; a large
# set's album comes sixty cards to a page, and draws its art only near the
# viewport. Between 720 and 1179px the grid's sets are a strip above it.
class CollectionSetTest < ApplicationSystemTestCase
  include CatalogSeeds
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
