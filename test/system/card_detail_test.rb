require "application_system_test_case"
require_relative "../support/catalog_seeds"
require_relative "../support/game_packs"

# A card's detail, "FICHE DE LA CARTE" (CAP-7, story 4.3; epic 10 R2, R6):
# opened from a tome's owned face, from an empty slot (the faded card back,
# from a set's grid and from the whole season's), from an opened pack's
# faces; on a phone the sub-view: its heading takes the focus as it opens,
# ◀ ▶ and a swipe step through the set, replacing the URL, "◀ Grille" and
# browser Back return to the grid at its scroll with the focus on its link
# to the card last shown (the whole season's collection when opened from
# it, not the tome's grid), the actions stay in view; under reduced motion a
# step does not move.
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
    page.driver.browser.manage.window.resize_to(*SCREEN_SIZE)
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

  def in_tome_path(id, season) = "/en/cards/#{slug(id)}/seasons/#{season.number}?set_key=action-1&set_kind=tome"

  def current_url_path = evaluate_script("location.pathname + location.search")

  def scroll_y = evaluate_script("window.scrollY")

  # Waits for the page to be scrolled to `y` (Turbo restores a page's
  # scroll once it has rendered it, after the URL has changed).
  def assert_scrolled_to(y)
    page.document.synchronize(Capybara.default_max_wait_time) do
      raise Capybara::ExpectationNotMet, "scrolled to #{scroll_y}, not #{y}" unless (scroll_y - y).abs <= 2
    end
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

  test "a player opens an owned card from a tome: its face, every fact, their copies, the Steam link, its sets back to the tome" do
    season = publish_sets_draft
    player = accounts_players(:player)
    id = members(season, "action-1").first
    card = Catalog::CardSeason.find(id).card
    Catalog::CardText.where(card_id: card.id, locale: "en").update_all(short_description: "A seed of a game.")
    Game::Holding.create!(player_id: player.id, card_season_id: id, quantity: 2)
    sign_in(player)

    visit library_set_path(locale: :en, kind: "tome", key: "action-1")
    find(".collection-grid a.card-link", match: :first).click

    assert_current_path in_tome_path(id, season)
    assert_selector ".card-detail h1", text: "Seed 0"
    assert_selector ".card-detail__kicker", text: "CARD FILE"
    assert_selector ".card-detail__card .card.card--l"
    assert_selector ".card-detail__description", text: "A seed of a game."
    assert_selector ".card-detail__fact", text: /COPIES\s+2 copies/
    assert_selector ".card-detail__notice", text: "This game and its image belong to their respective owners. gameble is not affiliated with Valve or Steam."
    link = find(".card-detail__actions a.card-detail__store")
    assert_equal [ card.store_url, "_blank" ], [ link[:href], link[:target] ]
    assert_equal "See on Steam (new tab)", link.evaluate_script("this.textContent").squish
    assert_selector ".card-detail__actions button", text: "SHARE"
    # The desktop shows no ◀ ▶ nor position line; the number is in the header.
    assert_no_selector ".card-detail__nav"
    assert_no_selector ".card-detail__position"
    assert_no_selector ".top-bar__phone-back"
    assert_selector ".top-bar__start > a.button[href='/en']", text: "BRIDGE"
    assert_selector ".card-detail__number", text: "S#{season.number} · #"
    take_screenshot

    click_on "Action · Tome 1"
    assert_selector ".set-row[aria-current=page] .set-row__name", text: /\AAction · Tome 1\z/i
  end

  test "a visitor clicks an empty slot: the Standard back, faded, with the card's facts" do
    season = publish_sets_draft
    id = members(season, "p").first
    card = Catalog::CardSeason.find(id).card

    visit library_set_path(locale: :fr, kind: "publisher", key: "p")
    find(".collection-grid a.card-link .missing-slot", match: :first).click

    assert_current_path "/fr/cards/#{card.slug}/seasons/#{season.number}?set_key=p&set_kind=publisher"
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

  test "from the whole season's collection, a missing slot opens its card on the faded back, browsing its tome" do
    season = publish_sets_draft

    visit library_path(locale: :en)
    link = find(".collection-grid a.card-link[href*='set_kind=tome']", match: :first)
    href = link[:href]
    link.find(".missing-slot").click

    assert_current_path URI(href).request_uri
    assert_match(/\?set_key=[a-z]+-\d&set_kind=tome\z/, current_url_path)
    assert_selector ".card-detail__back img[src*='back-standard']"
    assert_selector ".card-detail__not-owned", text: "NOT OWNED"
    assert_no_selector ".card-detail__card .card"
    assert_selector ".card-detail__sets a", text: /TOME/i
    assert_equal season.number.to_s, current_url_path[%r{/seasons/(\d+)}, 1]
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

  test "on a phone: ▶ and a swipe step through the tome replacing the URL, the actions in view; ◀ Grille and Back return to the grid at its scroll" do
    season = publish_sets_draft
    player = accounts_players(:player)
    ids = members(season, "action-1")
    ids.first(6).each { Game::Holding.create!(player_id: player.id, card_season_id: it, quantity: 1) }
    sign_in(player)
    page.driver.browser.manage.window.resize_to(*PHONE)

    visit library_set_path(locale: :en, kind: "tome", key: "action-1")
    slot = find(".collection-grid > li:nth-child(4) a.card-link")
    slot.execute_script("this.scrollIntoView({ block: 'center' })")
    grid_scroll = scroll_y
    assert_operator grid_scroll, :>, 0
    entries = evaluate_script("history.length")
    slot.click

    assert_current_path in_tome_path(ids[3], season)
    assert_selector ".card-detail h1", text: title(ids[3])
    # The sub-view opened: its heading has the focus.
    assert_focused ".card-detail h1"
    assert_selector ".card-detail__position", text: "· 4 / 25 · SWIPE TO BROWSE"
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
    assert_selector ".card-detail__position", text: "· 5 / 25 ·"
    assert_equal in_tome_path(ids[4], season), current_url_path
    assert_equal entries + 1, evaluate_script("history.length")
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
    assert_selector ".card-detail__position", text: "· 6 / 25 ·"
    assert_equal in_tome_path(ids[5], season), current_url_path
    swipe(120)
    assert_selector ".card-detail__position", text: "· 5 / 25 ·"
    # A vertical drag is no swipe.
    execute_script(<<~JS)
      const stage = document.querySelector(".card-detail__stage")
      const event = (type, clientY) => new PointerEvent(type, { bubbles: true, pointerId: 8, pointerType: "touch", isPrimary: true, clientX: 200, clientY })
      stage.dispatchEvent(event("pointerdown", 300)); stage.dispatchEvent(event("pointerup", 100))
    JS
    assert_equal entries + 1, evaluate_script("history.length")
    assert_selector ".card-detail__position", text: "· 5 / 25 ·"

    find(".top-bar__phone-back").click
    assert_current_path library_set_path(locale: :en, kind: "tome", key: "action-1")
    assert_selector ".collection-grid"
    assert_scrolled_to grid_scroll
    # The focus is on the grid's link to the card last shown, the grid still
    # at its scroll.
    assert_focused ".collection-grid > li:nth-child(5) a.card-link"
    assert_scrolled_to grid_scroll

    # Browser Back from the detail does the same.
    go_forward
    assert_selector ".card-detail__position", text: "· 5 / 25 ·"
    # Turbo renders the cached detail, then scrolls it to its top: going
    # back before that would file the detail's scroll under the grid's entry.
    assert_scrolled_to 0
    go_back
    assert_current_path library_set_path(locale: :en, kind: "tome", key: "action-1")
    assert_selector ".collection-grid"
    assert_scrolled_to grid_scroll
    assert_focused ".collection-grid > li:nth-child(5) a.card-link"
  end

  test "on a phone, a card opened from the whole season's collection goes back there with ◀ Grille, not to its tome's grid" do
    season = publish_sets_draft
    page.driver.browser.manage.window.resize_to(*PHONE)

    visit library_path(locale: :en)
    # A card of this page whose next card in its tome is on the page too.
    shown = all(".collection-grid a.card-link", visible: :all).map { URI(it[:href]) }
      .to_h { [ it.path[%r{\A/en/cards/([^/]+)/}, 1], Rack::Utils.parse_query(it.query)["set_key"] ] }
    key, from, to = shown.values.compact.uniq.filter_map { |tome|
      slugs = members(season, tome).map { slug(it) }
      pair = slugs.each_cons(2).reverse_each.find { |a, b| shown.key?(a) && shown.key?(b) }
      [ tome, *pair ] if pair
    }.first
    assert key, "a card and the next one in its tome should be on the first page"

    slot = find(".collection-grid a.card-link[href^='/en/cards/#{from}/']")
    slot.execute_script("this.scrollIntoView({ block: 'center' })")
    grid_scroll = scroll_y
    assert_operator grid_scroll, :>, 0
    slot.click

    assert_selector ".card-detail h1"
    assert_match %r{\A/en/cards/#{from}/seasons/#{season.number}\?set_key=#{key}&set_kind=tome\z}, current_url_path
    assert_focused ".card-detail h1"
    find(".card-detail__nav--next").click
    assert_selector ".card-detail h1"
    page.document.synchronize { raise Capybara::ExpectationNotMet unless current_url_path.start_with?("/en/cards/#{to}/") }
    assert_no_selector "html[data-sub-view-step]", visible: :all

    # Its href is the tome's grid, but the season's collection, an earlier
    # entry, is where the sub-view was opened: back through history to it.
    assert_equal "/en/library/tome/#{key}", URI(find(".top-bar__phone-back")[:href]).path
    find(".top-bar__phone-back").click
    assert_current_path library_path(locale: :en)
    assert_selector ".collection-grid"
    assert_scrolled_to grid_scroll
    assert_focused ".collection-grid a.card-link[href^='/en/cards/#{to}/']"
    assert_scrolled_to grid_scroll
  end

  test "on a phone the ends of a set are disabled, and a card opened without the grid goes back to it by a plain visit" do
    season = publish_sets_draft
    ids = members(season, "action-1")
    page.driver.browser.manage.window.resize_to(*PHONE)

    visit in_tome_path(ids.first, season)
    assert_selector ".card-detail__nav--previous[disabled]"
    swipe(120)
    assert_selector ".card-detail__position", text: "· 1 / 25 ·"
    assert_equal in_tome_path(ids.first, season), current_url_path

    find(".top-bar__phone-back").click
    assert_current_path library_set_path(locale: :en, kind: "tome", key: "action-1")
  end

  test "a step from the keyboard keeps the focus on the same control" do
    season = publish_sets_draft
    ids = members(season, "action-1")
    page.driver.browser.manage.window.resize_to(*PHONE)

    visit in_tome_path(ids[1], season)
    find(".card-detail__nav--next").execute_script("this.focus()")
    find(".card-detail__nav--next").send_keys(:enter)

    assert_selector ".card-detail__position", text: "· 3 / 25 ·"
    assert evaluate_script("document.activeElement.matches('.card-detail__nav--next')"), "the focus should stay on ▶"
  end

  test "a step runs in a View Transition, none under reduced motion" do
    season = publish_sets_draft
    ids = members(season, "action-1")
    page.driver.browser.manage.window.resize_to(*PHONE)
    visit in_tome_path(ids[1], season)
    count_transitions = <<~JS
      window.transitions = 0
      const start = document.startViewTransition.bind(document)
      document.startViewTransition = (update) => { window.transitions++; return start(update) }
    JS

    execute_script(count_transitions)
    find(".card-detail__nav--next").click
    assert_selector ".card-detail__position", text: "· 3 / 25 ·"
    assert_equal 1, evaluate_script("window.transitions")
    # The star field did not shift: the screen did not change.
    assert_no_selector ".atmosphere__stars[style*='--star-shift']", visible: :all

    execute_script("document.documentElement.dataset.motion = 'reduced'")
    find(".card-detail__nav--next").click
    assert_selector ".card-detail__position", text: "· 4 / 25 ·"
    assert_equal 1, evaluate_script("window.transitions")
    assert_no_selector "html[data-sub-view-step]", visible: :all
    assert_equal "same-origin", evaluate_script("document.querySelector('meta[name=view-transition]').content")
  end
end
