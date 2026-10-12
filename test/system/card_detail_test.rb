require "application_system_test_case"
require_relative "../support/catalog_seeds"
require_relative "../support/game_packs"

# A card's detail, "FICHE DE LA CARTE": opened from a theme's owned face,
# from an empty slot (the faded card back, from a set's grid and from the
# whole season's), from an opened pack's faces, walking the card's theme on
# the desktop too; from a filtered, searched grid, ◀ ▶ walk that grid as
# shown and the way back returns to it with its filters; on a phone the
# sub-view: its heading takes the focus as it opens, ◀ ▶ and a swipe step
# through the grid, replacing the URL, "◀ Grille" and browser Back return
# to the grid at its scroll with the focus on its link to the card last
# shown, the actions stay in view; under reduced motion a step does not
# move.
class CardDetailTest < ApplicationSystemTestCase
  include CatalogSeeds
  include GamePacks

  PHONE = [ 390, 844 ].freeze

  setup do
    OmniAuth.config.test_mode = true
  end

  teardown do
    OmniAuth.config.mock_auth.delete(:steam)
    OmniAuth.config.test_mode = false
  end

  def sign_in(player)
    OmniAuth.config.mock_auth[:steam] = OmniAuth::AuthHash.new(provider: "steam", uid: "https://steamcommunity.com/openid/id/#{player.steam_id}")
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

  # A card's detail walking the collection grid of `context` (its filters,
  # search and set), as the grid's links write it.
  def in_grid_path(id, season, context) = "/en/cards/#{slug(id)}/seasons/#{season.number}?#{{ grid: context }.to_query}"

  def set_grid = { key: "horror", kind: "theme", q: "", state: %w[all] }

  def current_url_path = evaluate_script("location.pathname + location.search")

  def scroll_y = evaluate_script("window.scrollY")

  # Waits for the page to be scrolled to `y` (Turbo restores a page's
  # scroll once it has rendered it, after the URL has changed).
  def assert_scrolled_to(y)
    page.document.synchronize(Capybara.default_max_wait_time) do
      raise Capybara::ExpectationNotMet, "scrolled to #{scroll_y}, not #{y}" unless (scroll_y - y).abs <= 2
    end
  end

  # Waits for the browser to draw `count` frames, so the events a frame
  # dispatches (scroll among them) have run.
  def wait_for_frames(count = 2)
    evaluate_async_script(<<~JS, count)
      const [ count, done ] = arguments
      const step = (left) => left === 0 ? done() : requestAnimationFrame(() => step(left - 1))
      step(count)
    JS
  end

  # Waits for the focus to be on an element matching `selector`.
  def assert_focused(selector)
    page.document.synchronize(Capybara.default_max_wait_time) do
      focused = evaluate_script("document.activeElement?.outerHTML.slice(0, 120)")
      raise Capybara::ExpectationNotMet, "focus on #{focused}, not #{selector}" unless evaluate_script("document.activeElement?.matches(#{selector.to_json})")
    end
  end

  # A finger moving `dx` px sideways across the stage, as touch pointer
  # events.
  def swipe(dx)
    execute_script(<<~JS, dx)
      const stage = document.querySelector(".card-detail__stage")
      const box = stage.getBoundingClientRect()
      const x = box.left + box.width / 2, y = box.top + box.height / 2
      const event = (type, clientX) => new PointerEvent(type, { bubbles: true, pointerId: 7, pointerType: "touch", isPrimary: true, clientX, clientY: y })
      stage.dispatchEvent(event("pointerdown", x))
      stage.dispatchEvent(event("pointermove", x + arguments[0] / 2))
      stage.dispatchEvent(event("pointerup", x + arguments[0]))
    JS
  end

  test "a player opens an owned card from a theme: its face, every fact, their copies, the Steam link, its sets back to the theme" do
    season = publish_sets_draft
    player = accounts_players(:player)
    id = members(season, "horror").first
    card = Catalog::CardSeason.find(id).card
    Catalog::CardText.where(card_id: card.id, locale: "en").update_all(short_description: "A seed of a game.")
    Game::Holding.create!(player_id: player.id, card_season_id: id, quantity: 2)
    sign_in(player)

    visit library_set_path(locale: :en, kind: "theme", key: "horror")
    find(".collection-grid a.card-link", match: :first).click

    assert_current_path in_grid_path(id, season, set_grid.except(:state))
    assert_selector ".card-detail h1", text: title(id)
    assert_selector ".card-detail__fact", text: /GENRE\s+Horror/i
    assert_equal [ "Horror", "Pirates" ], all(".card-detail__sets a").map { it.text.strip }
    assert_selector ".card-detail__kicker", text: "CARD FILE"
    assert_selector ".card-detail__card .card.card--l"
    assert_selector ".card-detail__description", text: "A seed of a game."
    assert_selector ".card-detail__fact", text: /COPIES\s+2 copies/
    link = find(".card-detail__actions a.card-detail__store")
    assert_equal [ card.store_url, "_blank" ], [ link[:href], link[:target] ]
    assert_equal "See on Steam (new tab)", link.evaluate_script("this.textContent").squish
    assert_selector ".card-detail__actions button", text: "SHARE"
    # The desktop shows ◀ ▶ (the grid of owned cards holds this one only),
    # no position line; the number is in the header.
    assert_selector "button.card-detail__nav--previous[disabled]"
    assert_selector "button.card-detail__nav--next[disabled]"
    assert_no_selector ".card-detail__position"
    assert_no_selector ".top-bar__phone-back"
    assert_selector ".top-bar__start > a.top-bar__home[href='/en'][aria-label='gameble, command bridge']"
    assert_no_selector ".top-bar__start > a.top-bar__bridge"
    assert_selector ".card-detail__number", text: "S#{season.number} · #"
    take_screenshot

    click_on "Horror"
    assert_selector ".set-row[aria-current=page] .set-row__name", text: /\AHorror\z/i
  end

  test "a holder reposts a card from its detail: a toast, the button stays, and the feed opens on the repost" do
    player = accounts_players(:player)
    Game::Holding.create!(player_id: player.id, card_season_id: catalog_card_seasons(:portal_one).id, quantity: 1)
    sign_in(player)
    player.update!(persona_name: "Hugo")

    visit card_path(locale: :fr, slug: "portal")
    within(".card-detail__actions") { click_on "Reposter" }

    assert_selector "#toasts .toast--notice", text: /carte repostée dans le fil\./i
    assert_selector ".card-detail__actions button", text: "REPOSTER"
    assert_selector ".card-detail h1", text: "Portal"

    within(".card-detail__actions") { click_on "Reposter" }
    assert_selector "#toasts .toast--notice", text: /carte repostée dans le fil\./i, count: 2

    visit feed_path(locale: :fr)
    assert_selector ".feed__entry", count: 2
    within(first(".feed__entry")) do
      assert_selector ".feed__sentence", text: "Hugo a reposté Portal."
      assert_selector ".feed__tag--repost", text: "REPOST"
      assert_selector ".feed__thumb--framed.feed__thumb--epic"
    end
  end

  test "no repost on a card not held, nor for a visitor" do
    player = accounts_players(:player)
    sign_in(player)

    visit card_path(locale: :en, slug: "portal")
    assert_selector ".card-detail h1", text: "Portal"
    assert_no_button "Repost"

    sign_out
    assert_signed_out
    visit card_path(locale: :en, slug: "portal", set_kind: "publisher", set_key: "valve")
    assert_selector ".card-detail h1", text: "Portal"
    assert_no_button "Repost"
  end

  test "a visitor clicks an empty slot: the Standard back, faded, with the card's facts" do
    season = publish_sets_draft
    id = members(season, "pirates").first
    card = Catalog::CardSeason.find(id).card

    visit library_set_path(locale: :fr, kind: "theme", key: "pirates")
    find(".collection-grid a.card-link .missing-slot", match: :first).click

    assert_current_path "/fr/cards/#{card.slug}/seasons/#{season.number}?#{{ grid: { key: "pirates", kind: "theme", q: "" } }.to_query}"
    assert_selector ".card-detail h1", text: card.texts.find_by!(locale: "fr").title
    assert_selector ".card-detail__back img[src*='back-standard']"
    assert_equal 0.55, find(".card-detail__back-image").evaluate_script("Number(getComputedStyle(this).opacity)")
    assert_selector ".card-detail__not-owned", text: "NON POSSÉDÉE"
    assert_no_selector ".card-detail__card .card"
    assert_selector ".card-detail__fact dt", text: "RARETÉ"
    assert_no_selector ".card-detail__copies"
    assert_no_selector ".card-detail__share-button"
    assert_selector ".card-detail__store[href$='l=french']"
    take_screenshot

    # A long title stays on the back's bottom plate, two lines at most,
    # clear of the back's ring (which ends 214px down).
    card.texts.find_by!(locale: "fr").update!(title: "Un titre de jeu vraiment très long qui ne tiendrait jamais sur deux lignes")
    visit current_url
    plate_top, title_lines = evaluate_script(<<~JS)
      (() => {
        const back = document.querySelector(".card-detail__back").getBoundingClientRect()
        const title = document.querySelector(".card-detail__back-title")
        const plate = document.querySelector(".card-detail__back-plate").getBoundingClientRect()
        return [ plate.top - back.top, Math.round(title.getBoundingClientRect().height / parseFloat(getComputedStyle(title).lineHeight)) ]
      })()
    JS
    assert_operator plate_top, :>=, 216
    assert_operator title_lines, :<=, 2
  end

  test "from the whole season's collection, a missing slot opens its card on the faded back, walking the collection" do
    season = publish_sets_draft

    visit library_path(locale: :en)
    links = all(".collection-grid a.card-link").map { it[:href] }
    find(".collection-grid > li:nth-child(2) .missing-slot").click

    assert_current_path URI(links[1]).request_uri
    assert_match(/\?grid%5Bq%5D=\z/, current_url_path)
    assert_selector ".card-detail__back img[src*='back-standard']"
    assert_selector ".card-detail__not-owned", text: "NOT OWNED"
    assert_no_selector ".card-detail__card .card"
    assert_equal season.number.to_s, current_url_path[%r{/seasons/(\d+)}, 1]
    # ◀ ▶ lead to the collection's first and third cards, on the desktop too.
    assert_equal [ links[0], links[2] ].map { URI(it).request_uri }, all("a.card-detail__nav").map { URI(it[:href]).request_uri }
  end

  test "an opened pack's faces lead to their cards" do
    player = accounts_players(:player)
    pack = create_pack(player, cards: fixture_tier_ids, opened_at: 1.minute.ago)
    sign_in(player)

    visit pack_path(pack.token, locale: :en)
    assert_selector ".pack-result__card a.card-link .card.card--m", count: 5
    find(".pack-result__card:nth-child(4) a.card-link").click

    assert_current_path "/en/cards/portal/seasons/1"
    assert_selector ".card-detail h1", text: "Portal"
    assert_selector ".card-detail__card .card.card--l"
    assert_selector ".card-detail__description", text: "A puzzle game of portals."
    assert_selector ".card-detail__sets a", text: "Valve"
    # The pack's page keeps walking the card's set, on the desktop too.
    assert_selector "button.card-detail__nav--previous[disabled]"
    assert_selector "button.card-detail__nav--next[disabled]"
  end

  test "the links to a card take the keyboard focus with a visible outline" do
    player = accounts_players(:player)
    pack = create_pack(player, cards: fixture_tier_ids, opened_at: 1.minute.ago)
    sign_in(player)

    visit pack_path(pack.token, locale: :en)
    link = find(".pack-result__card:first-child a.card-link")
    link.execute_script("this.focus()")

    assert_equal "Tin Soldier, Common, season 1", link["aria-label"]
    assert_equal "inline-block", link.evaluate_script("getComputedStyle(this).display")
    assert_not_equal "none", link.evaluate_script("getComputedStyle(this).outlineStyle")
  end

  test "on a phone: ▶ and a swipe step through the theme's grid replacing the URL, the actions in view; ◀ Grille and Back return to the grid at its scroll" do
    season = publish_sets_draft
    player = accounts_players(:player)
    ids = members(season, "horror")
    ids.first(6).each { Game::Holding.create!(player_id: player.id, card_season_id: it, quantity: 1) }
    sign_in(player)
    page.driver.browser.manage.window.resize_to(*PHONE)
    grid_path = library_set_path(locale: :en, kind: "theme", key: "horror", state: %w[all])

    visit grid_path
    slot = find(".collection-grid > li:nth-child(4) a.card-link")
    slot.execute_script("this.scrollIntoView({ block: 'center' })")
    grid_scroll = scroll_y
    assert_operator grid_scroll, :>, 0
    entries = evaluate_script("history.length")
    slot.click

    assert_current_path in_grid_path(ids[3], season, set_grid)
    assert_selector ".card-detail h1", text: title(ids[3])
    # The sub-view opened: its heading has the focus.
    assert_focused ".card-detail h1"
    assert_selector ".card-detail__position", text: "· 4 / 16 · SWIPE TO BROWSE"
    assert_no_selector ".card-detail__number"
    assert_selector ".top-bar__phone-back", text: "GRID"
    assert_no_selector ".top-bar__start > a.button[href='/en']"
    # The actions are in view, above the tab bar, without scrolling.
    in_view = evaluate_script(<<~JS)
      (() => {
        const actions = document.querySelector(".card-detail__actions").getBoundingClientRect()
        const tabs = document.querySelector(".tab-bar").getBoundingClientRect()
        return actions.top >= 0 && actions.bottom <= tabs.top + 1
      })()
    JS
    assert in_view, "the actions should be in view above the tab bar"
    assert page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth"), "the page should not scroll sideways"
    take_screenshot

    find(".card-detail__nav--next").click
    assert_selector ".card-detail__position", text: "· 5 / 16 ·"
    assert_equal in_grid_path(ids[4], season, set_grid), current_url_path
    assert_history_length entries + 1
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

    swipe(-120)
    assert_selector ".card-detail__position", text: "· 6 / 16 ·"
    assert_equal in_grid_path(ids[5], season, set_grid), current_url_path
    swipe(120)
    assert_selector ".card-detail__position", text: "· 5 / 16 ·"
    # A vertical drag is no swipe.
    execute_script(<<~JS)
      const stage = document.querySelector(".card-detail__stage")
      const event = (type, clientY) => new PointerEvent(type, { bubbles: true, pointerId: 8, pointerType: "touch", isPrimary: true, clientX: 200, clientY })
      stage.dispatchEvent(event("pointerdown", 300)); stage.dispatchEvent(event("pointerup", 100))
    JS
    assert_history_length entries + 1
    assert_selector ".card-detail__position", text: "· 5 / 16 ·"

    find(".top-bar__phone-back").click
    assert_current_path grid_path
    assert_selector ".collection-grid"
    assert_scrolled_to grid_scroll
    # The focus is on the grid's link to the card last shown, the grid still
    # at its scroll.
    assert_focused ".collection-grid > li:nth-child(5) a.card-link"
    assert_scrolled_to grid_scroll

    # Browser Back from the detail does the same.
    go_forward
    assert_selector ".card-detail__position", text: "· 5 / 16 ·"
    # Turbo renders the cached detail, then scrolls it to its top, and files
    # that scroll from the `scroll` event the next frame fires: going back
    # before that event would file the detail's 0 under the grid's entry.
    assert_scrolled_to 0
    wait_for_frames
    go_back
    assert_current_path grid_path
    assert_selector ".collection-grid"
    assert_scrolled_to grid_scroll
    assert_focused ".collection-grid > li:nth-child(5) a.card-link"
  end

  test "on a phone, from a filtered, searched collection ◀ ▶ walk it across its pages and ◀ Grille returns to it with its filters" do
    season = publish_sets_draft
    page.driver.browser.manage.window.resize_to(*PHONE)
    filters = { state: %w[missing], genre: %w[roguelike], q: "seed" }
    # The 75 cards whose main theme is roguelike: two pages, the 61st on the second.
    shown = (1..2).flat_map do |number|
      visit library_path(locale: :en, **filters, page: number)
      all(".collection-grid a.card-link").map { URI(it[:href]).path[%r{\A/en/cards/([^/]+)/}, 1] }
    end
    assert_equal 75, shown.size
    grid_path = library_path(locale: :en, **filters)

    visit grid_path
    slot = find(".collection-grid > li:nth-child(60) a.card-link")
    slot.execute_script("this.scrollIntoView({ block: 'center' })")
    grid_scroll = scroll_y
    slot.click

    assert_selector ".card-detail h1"
    assert_match %r{\A/en/cards/#{shown[59]}/seasons/#{season.number}\?grid}, current_url_path
    assert_selector ".card-detail__position", text: "· 60 / 75 ·"
    assert_selector ".top-bar__phone-back", text: "GRID"
    find(".card-detail__nav--next").click
    assert_selector ".card-detail__position", text: "· 61 / 75 ·"
    page.document.synchronize { raise Capybara::ExpectationNotMet unless current_url_path.start_with?("/en/cards/#{shown[60]}/") }
    assert_no_selector "html[data-sub-view-step]", visible: :all
    # The way back follows the card to the grid's second page.
    assert_selector ".top-bar__phone-back[href*='page=2']"
    swipe(120)
    assert_selector ".card-detail__position", text: "· 60 / 75 ·"
    assert_no_selector "html[data-sub-view-step]", visible: :all

    # The grid, an earlier entry, is restored at its scroll with its filters.
    find(".top-bar__phone-back").click
    assert_current_path grid_path
    assert_selector ".collection-grid"
    assert_scrolled_to grid_scroll
    assert_focused ".collection-grid > li:nth-child(60) a.card-link"
    assert_equal "seed", find("#collection-search").value
  end

  test "on a phone, once ◀ ▶ crossed onto another page of the grid, ◀ Grille leads to that page, showing the card last seen" do
    season = publish_sets_draft
    page.driver.browser.manage.window.resize_to(*PHONE)
    filters = { state: %w[missing], genre: %w[roguelike], q: "seed" }
    visit library_path(locale: :en, **filters, page: 2)
    second_page = all(".collection-grid a.card-link").map { URI(it[:href]).path }
    assert_operator second_page.size, :>, 0

    visit library_path(locale: :en, **filters)
    find(".collection-grid > li:nth-child(60) a.card-link").click
    assert_selector ".card-detail__position", text: "· 60 / 75 ·"
    find(".card-detail__nav--next").click
    assert_selector ".card-detail__position", text: "· 61 / 75 ·"
    assert_no_selector "html[data-sub-view-step]", visible: :all

    find(".top-bar__phone-back").click
    page.document.synchronize do
      raise Capybara::ExpectationNotMet, current_url_path unless URI(current_url_path).path == "/en/library" && Rack::Utils.parse_query(URI(current_url_path).query)["page"] == "2"
    end
    assert_selector ".collection-grid a.card-link[href^='#{second_page.first}']"
    assert_equal "seed", find("#collection-search").value
  end

  test "on the desktop, from a filtered collection ◀ ▶ walk it, and Back returns to it with its filters" do
    season = publish_sets_draft
    filters = { state: %w[all], genre: %w[rpg], q: "seed 1" }
    visit library_path(locale: :en, **filters)
    shown = all(".collection-grid a.card-link").map { URI(it[:href]).path[%r{\A/en/cards/([^/]+)/}, 1] }
    assert_operator shown.size, :>, 3

    find(".collection-grid > li:nth-child(2) a.card-link").click
    assert_selector ".card-detail h1"
    assert_no_selector ".card-detail__position"
    find(".card-detail__nav--next").click
    page.document.synchronize { raise Capybara::ExpectationNotMet unless current_url_path.start_with?("/en/cards/#{shown[2]}/seasons/#{season.number}?") }
    find(".card-detail__nav--previous").click
    page.document.synchronize { raise Capybara::ExpectationNotMet unless current_url_path.start_with?("/en/cards/#{shown[1]}/") }
    find(".card-detail__nav--previous").click
    page.document.synchronize { raise Capybara::ExpectationNotMet unless current_url_path.start_with?("/en/cards/#{shown[0]}/") }
    assert_selector "button.card-detail__nav--previous[disabled]"

    go_back
    assert_current_path library_path(locale: :en, **filters)
    assert_equal "seed 1", find("#collection-search").value
  end

  test "on a phone the ends of a set are disabled, and a card opened without the grid goes back to it by a plain visit" do
    season = publish_sets_draft
    ids = members(season, "horror")
    page.driver.browser.manage.window.resize_to(*PHONE)

    visit in_set_path(ids.first, season)
    assert_selector ".card-detail__nav--previous[disabled]"
    swipe(120)
    assert_selector ".card-detail__position", text: "· 1 / 16 ·"
    assert_equal in_set_path(ids.first, season), current_url_path

    find(".top-bar__phone-back").click
    assert_current_path library_set_path(locale: :en, kind: "theme", key: "horror")
  end

  test "a step from the keyboard keeps the focus on the same control" do
    season = publish_sets_draft
    ids = members(season, "horror")
    page.driver.browser.manage.window.resize_to(*PHONE)

    visit in_set_path(ids[1], season)
    find(".card-detail__nav--next").execute_script("this.focus()")
    find(".card-detail__nav--next").send_keys(:enter)

    assert_selector ".card-detail__position", text: "· 3 / 16 ·"
    assert evaluate_script("document.activeElement.matches('.card-detail__nav--next')"), "the focus should stay on ▶"
  end

  test "a step runs in a View Transition, none under reduced motion" do
    season = publish_sets_draft
    ids = members(season, "horror")
    page.driver.browser.manage.window.resize_to(*PHONE)
    visit in_set_path(ids[1], season)
    count_transitions = <<~JS
      window.transitions = 0
      const start = document.startViewTransition.bind(document)
      document.startViewTransition = (update) => { window.transitions++; return start(update) }
    JS

    execute_script(count_transitions)
    find(".card-detail__nav--next").click
    assert_selector ".card-detail__position", text: "· 3 / 16 ·"
    assert_equal 1, evaluate_script("window.transitions")
    # The star field did not shift: the screen did not change.
    assert_no_selector ".atmosphere__stars[style*='--star-shift']", visible: :all

    execute_script("document.documentElement.dataset.motion = 'reduced'")
    find(".card-detail__nav--next").click
    assert_selector ".card-detail__position", text: "· 4 / 16 ·"
    assert_equal 1, evaluate_script("window.transitions")
    assert_no_selector "html[data-sub-view-step]", visible: :all
    assert_equal "same-origin", evaluate_script("document.querySelector('meta[name=view-transition]').content")
  end

  # The history entry is pushed by Turbo a moment after the page shows the new
  # card, so the length is read again for up to two seconds before it is judged.
  # Chrome keeps at most 50 entries: a session that already holds 50 stays at 50.
  def assert_history_length(expected)
    expected = [ expected, 50 ].min
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 2
    length = evaluate_script("history.length")
    while length != expected && Process.clock_gettime(Process::CLOCK_MONOTONIC) < deadline
      sleep 0.05
      length = evaluate_script("history.length")
    end
    assert_equal expected, length
  end
end
