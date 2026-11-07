require "application_system_test_case"
require_relative "../support/catalog_seeds"
require_relative "../support/game_packs"
require_relative "../support/steam_sign_in"

# A card's detail on a phone, the sub-view of a grid: its heading takes the
# focus as it opens, ◀ ▶ step through the grid replacing the URL, and
# "◀ Grille" and browser Back return to the grid with the focus on its link
# to the card last shown; from a filtered, searched grid, ◀ ▶ walk that grid
# across its pages and the way back keeps its filters.
class CardDetailTest < ApplicationSystemTestCase
  include CatalogSeeds
  include GamePacks
  include SteamSignIn

  PHONE = [ 390, 844 ].freeze

  def sign_in(player)
    mock_steam_sign_in(player.steam_id)
    visit home_path(locale: :en)
    click_steam_sign_in
    assert_signed_in
  end

  def members(season, key)
    set = Catalog::Set.find_by!(season_id: season.id, key:)
    Catalog::SetMembership.where(set_id: set.id).order(:position, :id).pluck(:card_season_id)
  end

  def slug(id) = Catalog::CardSeason.find(id).card.slug

  def title(id) = Catalog::CardSeason.find(id).card.texts.find_by!(locale: "en").title

  def in_set_path(id, season) = "/en/cards/#{slug(id)}/seasons/#{season.number}?set_key=horror&set_kind=theme"

  def current_url_path = evaluate_script("location.pathname + location.search")

  def action_buttons
    evaluate_script(<<~JS)
      [ ...document.querySelectorAll(".card-detail__actions .button") ]
        .map((button) => [ button.textContent.replace(/\\s+/g, " ").trim(), button.classList.contains("button--primary") ])
    JS
  end

  # Waits for the focus to be on an element matching `selector`.
  def assert_focused(selector)
    page.document.synchronize(Capybara.default_max_wait_time) do
      focused = evaluate_script("document.activeElement?.outerHTML.slice(0, 120)")
      raise Capybara::ExpectationNotMet, "focus on #{focused}, not #{selector}" unless evaluate_script("document.activeElement?.matches(#{selector.to_json})")
    end
  end


  test "on a phone: ▶ steps through the theme's grid replacing the URL; ◀ Grille and Back return to the grid, the focus on the card last shown" do
    season = publish_sets_draft
    player = accounts_players(:player)
    ids = members(season, "horror")
    ids.first(6).each { Game::Holding.create!(player_id: player.id, card_season_id: it, quantity: 1) }
    sign_in(player)
    page.driver.browser.manage.window.resize_to(*PHONE)
    grid_path = library_set_path(locale: :en, kind: "theme", key: "horror", state: %w[all])

    visit grid_path
    find(".collection-grid > li:nth-child(4) a.card-link").click

    assert_current_path in_set_path(ids[3], season)
    assert_selector ".card-detail h1", text: title(ids[3])
    # The sub-view opened: its heading has the focus.
    assert_focused ".card-detail h1"
    assert_selector ".card-detail__position", text: "· 4 / 16 · SWIPE TO BROWSE"
    assert_no_selector ".card-detail__number"
    assert_selector ".top-bar__phone-back", text: "GRID"
    assert_no_selector ".top-bar__start > a.button[href='/en']"
    assert_equal [ [ "Repost", true ], [ "Add to showcase", false ], [ "Share", false ], [ "See on Steam (new tab)", false ] ], action_buttons

    find(".card-detail__nav--next").click
    assert_selector ".card-detail__position", text: "· 5 / 16 ·"
    assert_current_path in_set_path(ids[4], season)
    # The page's title follows the card.
    assert_selector ".card-detail h1", text: title(ids[4])
    assert_title(/\A#{title(ids[4])} — /)
    assert_no_selector "html[data-sub-view-step]", visible: :all
    # Once the step is over, the page keeps its head: language, viewport,
    # View Transitions (layouts/turbo_rails/frame.html.erb).
    assert_equal [ "en", "same-origin", 1 ], evaluate_script(<<~JS)
      [ document.documentElement.lang, document.querySelector("meta[name=view-transition]")?.content,
        document.querySelectorAll("meta[name=viewport]").length ]
    JS

    find(".top-bar__phone-back").click
    assert_current_path grid_path
    assert_focused ".collection-grid > li:nth-child(5) a.card-link"

    # Browser Back from the detail does the same: the step replaced its entry.
    go_forward
    assert_selector ".card-detail__position", text: "· 5 / 16 ·"
    go_back
    assert_current_path grid_path
    assert_focused ".collection-grid > li:nth-child(5) a.card-link"
  end

  test "on a phone, from a filtered, searched collection ◀ ▶ walk it across its pages and ◀ Grille returns to it with its filters" do
    season = publish_sets_draft
    page.driver.browser.manage.window.resize_to(*PHONE)
    filters = { state: %w[missing], genre: %w[roguelike], q: "seed" }
    # The 83 cards whose main theme is roguelike: two pages, the 61st on the second.
    shown = (1..2).flat_map do |number|
      visit library_cards_path(locale: :en, **filters, page: number)
      all(".collection-grid a.card-link").map { URI(it[:href]).path[%r{\A/en/cards/([^/]+)/}, 1] }
    end
    assert_equal 83, shown.size
    grid_path = library_cards_path(locale: :en, **filters)

    visit grid_path
    find(".collection-grid > li:nth-child(60) a.card-link").click

    assert_selector ".card-detail h1"
    assert_match %r{\A/en/cards/#{shown[59]}/seasons/#{season.number}\?grid}, current_url_path
    assert_selector ".card-detail__position", text: "· 60 / 83 ·"
    assert_selector ".top-bar__phone-back", text: "GRID"
    find(".card-detail__nav--next").click
    assert_selector ".card-detail__position", text: "· 61 / 83 ·"
    page.document.synchronize { raise Capybara::ExpectationNotMet unless current_url_path.start_with?("/en/cards/#{shown[60]}/") }
    assert_no_selector "html[data-sub-view-step]", visible: :all
    # The way back follows the card to the grid's second page.
    assert_selector ".top-bar__phone-back[href*='page=2']"
    find(".card-detail__nav--previous").click
    assert_selector ".card-detail__position", text: "· 60 / 83 ·"
    assert_no_selector "html[data-sub-view-step]", visible: :all

    # The grid, an earlier entry, is restored with its filters.
    find(".top-bar__phone-back").click
    assert_current_path grid_path
    assert_selector ".collection-grid"
    assert_focused ".collection-grid > li:nth-child(60) a.card-link"
    assert_equal "seed", find("#collection-search").value
  end

  test "a step from the keyboard keeps the focus on the same control" do
    season = publish_sets_draft
    ids = members(season, "horror")
    page.driver.browser.manage.window.resize_to(*PHONE)

    visit in_set_path(ids[1], season)
    find(".card-detail__nav--next").execute_script("this.focus()")
    find(".card-detail__nav--next").send_keys(:enter)

    assert_selector ".card-detail__position", text: "· 3 / 16 ·"
    assert_focused ".card-detail__nav--next"
  end
end
