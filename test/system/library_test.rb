require "application_system_test_case"
require_relative "../support/catalog_seeds"
require_relative "../support/game_packs"
require_relative "../support/game_sets"
require_relative "../support/steam_sign_in"

# The collection: a player reaches its entry from the hub's menu 02 or the
# phone's COLLECTION tab, picks a set and sees its progress, their faces with
# their copies and the missing cards not owned, on a desktop and a 390 × 844 phone
# without sideways scroll; the grid of every card, with its FILTRES zone and
# search, narrows without losing focus; the cards of a pack just opened are
# new until a grid has shown them; a visitor reads the grid in plain faces.
class LibraryTest < ApplicationSystemTestCase
  include CatalogSeeds
  include GamePacks
  include GameSets
  include SteamSignIn

  setup do
    @season = publish_sets_draft
    @player = accounts_players(:player)
    @theme = members("horror")
    @theme.first(3).each_with_index do |card_season_id, index|
      Game::Holding.create!(player_id: @player.id, card_season_id:, quantity: index == 1 ? 2 : 1)
    end
    mock_steam_sign_in(@player.steam_id)
  end

  def members(key)
    set = Catalog::Set.find_by!(season_id: @season.id, key:)
    Catalog::SetMembership.where(set_id: set.id).order(:position, :id).pluck(:card_season_id)
  end

  def sign_in
    visit home_path(locale: :en)
    click_steam_sign_in
    assert_signed_in
  end

  def assert_no_sideways_scroll
    assert page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth"), "the page should not scroll sideways"
  end

  def tile(key) = find(".set-tiles a.set-tile[href='#{library_set_path(locale: :en, kind: "theme", key:)}']")

  # The tile's sentence, its accessible name, read from its hidden span.
  def assert_tile(sentence) = assert_selector(".set-tiles a.set-tile > .visually-hidden", text: sentence, visible: :all)

  def iris(tile, property) = tile.evaluate_script("getComputedStyle(this).getPropertyValue('--iris-#{property}').trim()")

  # The iris is fully open once its radius and its light have reached their end.
  def opened?(tile) = iris(tile, "k") == "1" && iris(tile, "r") == "150%"

  def closed?(tile) = iris(tile, "k") == "0" && iris(tile, "r") == "0%"

  def face_style(tile, face, property) = tile.evaluate_script("getComputedStyle(this.querySelector('.set-tile__face--#{face}')).#{property}")

  # More sets in progress than a page holds: themes of three cards, two held.
  def start_more_sets(count)
    cards = Catalog::CardSeason.where(season_id: @season.id).order(:id).ids.last(count * 3)
    count.times do |index|
      members = cards.slice(index * 3, 3)
      insert_theme(members, key: "extra-#{index}", season: @season)
      hold_all(@player, members.first(2))
    end
  end

  def box(element) = element.evaluate_script("(() => { const r = this.getBoundingClientRect(); return [ r.x, r.y, r.width, r.height ].map(Math.round) })()")

  test "a player goes from menu 02 to a theme: its progress, their faces with their copies, the missing cards not owned" do
    sign_in

    within(".hub-menu") { click_on "Collection" }

    assert_current_path library_path(locale: :en)
    assert_selector ".top-bar__title", text: /\ACOLLECTION\z/
    assert_selector ".collection-status", text: %r{\AUnique cards:\s*3 / 150}
    assert_tile(/\AHorror, theme, 3 cards out of 16\b/)
    assert_tile(/\APirates, theme, 3 cards out of 8\b/)
    assert_no_selector ".collection-grid"
    take_screenshot

    tile("horror").click

    assert_current_path library_set_path(locale: :en, kind: "theme", key: "horror")
    assert_selector ".set-album__count", text: "3/16"
    assert_selector ".collection-grid > li", count: 16
    assert_selector ".collection-grid .card.card--grid", count: 16
    assert_selector ".collection-grid .card.card--grid:not(.card--not-owned)", count: 3
    assert_selector ".collection-slot__copies", text: "x2", count: 1
    assert_selector ".collection-grid a.card-link[aria-label$=', not owned'] .card.card--not-owned .card__lock", count: 13
    missing = Catalog::CardSeason.find(@theme[3])
    within(all(".collection-grid > li")[3]) do
      assert_selector ".card--not-owned .card__title", text: missing.card.texts.find_by!(locale: "en").title.upcase
      assert_selector ".card--not-owned .card__year", text: missing.card.release_date.year.to_s
      assert_no_selector ".collection-slot__copies, .collection-slot__new"
    end
    # The badges sit at the card's corners, inside the slot's painted box.
    corner = page.evaluate_script(<<~JS)
      (() => {
        const slot = document.querySelector(".collection-slot .collection-slot__copies").closest("li")
        const card = slot.querySelector(".card").getBoundingClientRect()
        const badge = slot.querySelector(".collection-slot__copies").getBoundingClientRect()
        const box = slot.getBoundingClientRect()
        return [ Math.round(badge.right - card.right), Math.round(card.top - badge.top), badge.right <= box.right, badge.top >= box.top ]
      })()
    JS
    assert_equal [ 6, 6, true, true ], corner
    assert_no_sideways_scroll
    take_screenshot

    find(".top-bar__home").click
    assert_current_path home_path(locale: :en)
  end

  test "EN COURS arrives after the page as tiles; keyboard focus opens the iris from the centre in place, reduced motion fades instead" do
    sign_in
    visit library_path(locale: :en)

    assert_selector "#set-search-field"
    assert_tile(/\APirates, theme, 3 cards out of 8\b/)
    assert_selector ".set-tiles a.set-tile .set-tile__card .card.card--s", minimum: 2
    assert_equal 2, page.evaluate_script("new Set([ ...document.querySelectorAll('.set-tiles > li') ].map((li) => Math.round(li.getBoundingClientRect().left))).size")
    first = find(".set-tiles a.set-tile", match: :first)
    at_rest = [ box(first), box(first.find(:xpath, "..")) ]
    assert closed?(first), "the verso should start hidden"

    find(".set-search__row a.button--primary").send_keys(:tab)
    assert_selector ".set-tiles > li:first-child > a.set-tile:focus"
    eventually("the focused tile should open its iris") { opened?(first) }
    assert_equal [ "50%", "50%" ], [ iris(first, "x"), iris(first, "y") ]
    assert_equal at_rest, [ box(first), box(first.find(:xpath, "..")) ]
    assert_selector ".set-tiles a.set-tile:focus .set-tile__face--verso .set-tile__cta", text: /VIEW THE ALBUM/i
    take_screenshot

    page.execute_script("document.documentElement.dataset.motion = 'reduced'")
    eventually("under reduced motion the verso should fade in with no mask") do
      face_style(first, "verso", "opacity") == "1" && face_style(first, "verso", "maskImage") == "none" && face_style(first, "recto", "opacity") == "1"
    end
    assert_equal at_rest, [ box(first), box(first.find(:xpath, "..")) ]
    page.execute_script("delete document.documentElement.dataset.motion")

    first.send_keys(:enter)
    assert_current_path library_set_path(locale: :en, kind: "theme", key: "pirates")
  end

  test "the iris opens from where the pointer entered the tile" do
    sign_in
    visit library_path(locale: :en)
    first = find(".set-tiles a.set-tile", match: :first)
    left, top, width, height = box(first)

    page.driver.browser.action.move_to(first.native, 60 - width / 2, 40 - height / 2).perform

    eventually("the iris should be centred on the pointer's entry") do
      (iris(first, "x").to_i - 60).abs <= 4 && (iris(first, "y").to_i - 40).abs <= 4
    end
    assert_equal [ left, top ], box(first).first(2)
  end

  test "no frame of the iris leaves a tile empty: both faces stay visible and opaque from the first frame to the last" do
    sign_in
    visit library_path(locale: :en)
    first = find(".set-tiles a.set-tile", match: :first)

    frames = page.evaluate_async_script(<<~JS, first)
      const tile = arguments[0], done = arguments[arguments.length - 1]
      const recto = tile.querySelector(".set-tile__face--recto"), verso = tile.querySelector(".set-tile__face--verso")
      const frames = []
      const started = performance.now()
      const sample = () => {
        const recto_style = getComputedStyle(recto), verso_style = getComputedStyle(verso)
        frames.push({
          radius: parseFloat(getComputedStyle(tile).getPropertyValue("--iris-r")),
          recto: [ recto_style.visibility, recto_style.opacity, recto_style.backgroundColor, recto_style.display ],
          verso: [ verso_style.visibility, verso_style.opacity, verso_style.backgroundColor, verso_style.display ],
          mask: verso_style.maskImage
        })
        if (performance.now() - started < 1400) requestAnimationFrame(sample); else done(frames)
      }
      tile.style.setProperty("--iris-r", "150%")
      tile.style.setProperty("--iris-k", "1")
      sample()
    JS

    assert_operator frames.size, :>, 20
    assert frames.any? { it["radius"].between?(10, 140) }, "the transition should have been sampled midway"
    assert frames.select { it["radius"].between?(10, 140) }.all? { it["mask"].include?("radial-gradient") }, "the verso is revealed by the iris mask midway"
    frames.each do |frame|
      assert_equal [ "visible", "1" ], frame["recto"].first(2)
      assert_equal [ "visible", "1" ], frame["verso"].first(2)
      assert_not_equal "rgba(0, 0, 0, 0)", frame["recto"][2]
      assert_not_equal "rgba(0, 0, 0, 0)", frame["verso"][2]
      assert_not_equal "none", frame["recto"][3]
      assert_not_equal "none", frame["verso"][3]
    end
  end

  test "EN COURS shows six sets, Load more adds the next ones, and the search finds any set as tiles in place of the lists" do
    start_more_sets(8)
    assert_equal 12, Game::SetBoard.call(@player, season: @season).in_progress.size
    sign_in
    visit library_path(locale: :en)

    assert_selector "#set-entry-in-progress-title ~ .set-tiles a.set-tile", count: 6
    find("turbo-frame.set-more a.button", text: /load more/i).click
    assert_selector ".set-tiles a.set-tile", count: 12
    assert_no_selector "turbo-frame.set-more a.button"
    assert_selector ".set-tiles a.set-tile:focus"

    fill_in "set-search-field", with: "rpg"
    assert_selector "#set-results-title", text: /\ARESULTS\z/
    assert_selector ".set-results .set-tiles a.set-tile[href='#{library_set_path(locale: :en, kind: "theme", key: "rpg")}']"
    assert_selector ".set-results .set-chip--none", text: /NO TIER/i
    assert_no_selector "#set-entry-in-progress-title"

    fill_in "set-search-field", with: ""
    assert_no_selector "#set-results-title"
    assert_selector "#set-entry-in-progress .set-tiles a.set-tile", count: 12
  end

  test "COMPLETED follows EN COURS: a complete set's tile turns to its tiers all reached and leads to its album" do
    (members("pirates") - @theme.first(3)).each { Game::Holding.create!(player_id: @player.id, card_season_id: it, quantity: 1) }
    sign_in
    visit library_path(locale: :en)

    assert_selector "#set-entry-in-progress-title ~ .set-tiles a.set-tile", minimum: 1
    assert_selector "#set-entry-completed-title", text: /\ACOMPLETED\z/
    complete = find("#set-entry-completed-title ~ .set-tiles a.set-tile[href='#{library_set_path(locale: :en, kind: "theme", key: "pirates")}']")
    assert_tile(/\APirates, theme, 8 cards out of 8, complete\z/)
    take_screenshot

    all("#set-entry-in-progress-title ~ .set-tiles a.set-tile").last.send_keys(:tab)
    assert_selector "#set-entry-completed-title ~ .set-tiles > li:first-child > a.set-tile:focus"
    eventually("the focused complete tile should open its iris") { opened?(complete) }
    within(complete) do
      assert_selector ".set-tile__node--reached", minimum: 1
      assert_no_selector ".set-tile__node--next, .set-tile__node--later"
      assert_selector ".set-tile__cta", text: /VIEW THE ALBUM/i
    end
    take_screenshot

    complete.click
    assert_current_path library_set_path(locale: :en, kind: "theme", key: "pirates")
    assert_selector ".set-album__count", text: "8/8"
  end

  test "a player who unticks the only state chip keeps every slot, as the form without JavaScript" do
    sign_in
    visit library_cards_path(locale: :en)
    find(".filters__summary").click
    assert_slots 60
    find(".filter-chip__text", text: /\AAll\z/i).click
    assert_slots 60
    assert_equal [ "ALL" ], all("[data-group=state] .filter-chip__box:checked", visible: :all).map { it.find(:xpath, "..").text.strip }
    assert_selector ".filters__count", visible: :hidden
    assert_selector "[role=status]", text: "150 cards shown.", visible: :all
  end

  test "on a 390 × 844 phone the tab leads here: the sets a column of tiles, then the grid with the RAPPORT folded, two cards a row" do
    page.driver.browser.manage.window.resize_to(390, 844)
    sign_in

    find(".tab-bar a.tab-bar__tab", text: /COLLECTION/i).click

    assert_current_path library_path(locale: :en)
    assert_selector ".collection-status__value", text: "3 / 150"
    assert_tile(/\AHorror, theme, 3 cards out of 16\b/)
    assert_equal 1, page.evaluate_script("new Set([ ...document.querySelectorAll('.set-tiles > li') ].map((li) => Math.round(li.getBoundingClientRect().left))).size")
    assert_no_sideways_scroll

    click_on "All cards"

    assert_current_path library_cards_path(locale: :en)
    assert_slots 60
    assert_no_selector ".report--panel", visible: true
    assert_no_selector ".collection-status__label", visible: true
    assert_selector ".collection-status__value", text: "3 / 150"
    tops = page.evaluate_script("[...document.querySelectorAll('.collection-grid > li')].slice(0, 3).map((slot) => Math.round(slot.getBoundingClientRect().top))")
    assert_equal tops[0], tops[1]
    assert_operator tops[2], :>, tops[0]
    assert_no_sideways_scroll

    find(".report--fold summary").click
    assert_selector ".report--fold[open] .report__row", text: /UNIQUE CARDS\s*3/
    take_screenshot

    visit library_set_path(locale: :en, kind: "theme", key: "horror")
    assert_selector ".set-album__count", text: "3/16"
    assert_selector ".collection-grid .card.card--grid", count: 16
    assert_selector ".collection-grid .card.card--grid.card--not-owned", count: 13
    faces = page.evaluate_script(<<~JS)
      [ ...document.querySelectorAll(".collection-grid .card") ].slice(2, 4).map((card) => {
        const box = card.getBoundingClientRect()
        return [ Math.round(box.top), Math.round(box.width), Math.round(box.height), card.classList.contains("card--not-owned") ]
      })
    JS
    assert_equal [ false, true ], faces.map(&:last)
    assert_equal faces[0].first(3), faces[1].first(3)
    assert_no_sideways_scroll
    take_screenshot
  end

  test "the FILTRES zone: chips narrow the grid, the zone keeps focus, the count follows, a search narrows as it is typed" do
    sign_in
    visit library_cards_path(locale: :en)
    assert_slots 60
    assert_no_selector ".filters__zone[open]"
    assert_no_selector ".filters__count", visible: true

    find(".filters__summary").click
    find(".filter-chip__text", text: /\AOwned\z/i).click
    assert_slots 3
    assert_selector ".filters__count", text: "1"
    assert_selector ".filters__clear", visible: true
    find(".filter-chip__text", text: /\AMissing\z/i).click
    assert_slots 60
    assert_selector ".collection-slot__copies", count: 3
    assert_selector ".filters__count", text: "2"
    find(".filter-chip__text", text: /\AOwned\z/i).click
    assert_selector ".collection-grid .card--not-owned", count: 57, visible: :all
    assert_no_selector ".collection-slot__copies"
    assert_selector ".filters__count", text: "1"

    # Back to the owned cards, then a genre none of them has.
    find(".filter-chip__text", text: /\AOwned\z/i).click
    find(".filter-chip__text", text: /\AMissing\z/i).click
    assert_slots 3
    assert_selector ".filters__count", text: "1"
    within("[data-group=genre]") do
      find(".filter-chip__text", text: /\ARPG\z/i).click
    end
    assert_selector ".collection-grid__empty", text: "Nothing matches these filters."
    assert_equal "RPG", page.evaluate_script("document.activeElement.parentElement.textContent.trim()")
    assert_selector ".filters__count", text: "2"

    # The search narrows as it is typed, and keeps the focus in the field.
    find(".filters__clear").click
    assert_slots 60
    assert_no_selector ".filters__count", visible: true
    title = Catalog::CardSeason.find(@theme.first).card.texts.find_by!(locale: "en").title
    field = find("#collection-search")
    field.click
    field.send_keys(title)
    assert_selector ".collection-grid .card__title", text: title.upcase
    assert_equal "collection-search", page.evaluate_script("document.activeElement.id")
    field.send_keys("zzzz")
    assert_selector ".collection-grid__empty"
    assert_equal "collection-search", page.evaluate_script("document.activeElement.id")
    assert_no_sideways_scroll
    take_screenshot
  end

  test "the cards of a pack just opened are new; once the grid has shown them, the next visit shows them no longer" do
    create_pack(@player, cards: @theme[3, 5], available_at: 1.year.ago, season: @season)
    sign_in
    assert Game::OpenPack.new.call(player: @player).success?

    visit library_set_path(locale: :en, kind: "theme", key: "horror")

    assert_selector ".collection-slot__new", count: 5, text: "NEW"
    assert_equal @theme[3, 5].map { Catalog::CardSeason.find(it).card.texts.find_by!(locale: "en").title.upcase },
      all(".collection-slot:has(.collection-slot__new) .card__title").map(&:text)
    take_screenshot

    visit library_cards_path(locale: :en, state: [ "new" ])

    assert_selector ".collection-slot__new", count: 5, text: "NEW"
    gained = Game::Holding.where(player_id: @player.id, card_season_id: @theme[3, 5]).maximum(:last_gained_at)
    assert_equal gained, wait_for_watermark

    visit library_set_path(locale: :en, kind: "theme", key: "horror")

    assert_selector ".collection-grid .card.card--grid:not(.card--not-owned)", count: 8
    assert_no_selector ".collection-slot__new"
  end

  test "a visitor reads the grid of every card in plain faces, with no ownership data" do
    visit library_cards_path(locale: :fr)

    assert_slots 60
    assert_no_selector ".collection-status"
    assert_no_selector ".collection-slot__new, .card--not-owned", visible: :all
    assert_no_selector ".report--panel", visible: :all
    assert_selector ".top-bar .top-bar__end a[href*='/sign-in']"
    assert_no_sideways_scroll
  end

  test "on a 360 × 740 phone a visitor keeps the Steam image, and two cards still fit a row" do
    page.driver.browser.manage.window.resize_to(360, 740)

    visit library_cards_path(locale: :en)

    assert_selector ".top-bar .top-bar__end a[href*='/sign-in']", visible: true
    assert_no_selector ".collection-status", visible: true
    tops = page.evaluate_script("[...document.querySelectorAll('.collection-grid > li')].slice(0, 3).map((slot) => Math.round(slot.getBoundingClientRect().top))")
    assert_equal tops[0], tops[1]
    assert_no_sideways_scroll
    take_screenshot
  end

  test "a player's filtered, searched grid appends its next page as its links come near, the status naming the cards shown" do
    held = Catalog::CardSeason.where(season_id: @season.id, main_theme: "roguelike").order(:number, :id).last(2)
    held.each { Game::Holding.create!(player_id: @player.id, card_season_id: it.id, quantity: 1) }
    held_paths = held.map { "/en/cards/#{it.card.slug}/" }
    sign_in
    filters = { state: %w[missing], genre: %w[roguelike], q: "seed" }
    visit library_cards_path(locale: :en, **filters, page: 2)
    second_page = all(".collection-grid a.card-link", minimum: 1).map { it[:href] }
    assert_equal 21, second_page.size

    visit library_cards_path(locale: :en, **filters)
    assert_slots 60
    scroll_to_pages

    assert_slots 81
    appended = all(".collection-grid > li:nth-child(n+61) a.card-link", visible: :all).map { it[:href] }
    assert_equal second_page, appended
    assert_selector ".collection-grid > li:nth-child(n+61) .card.card--not-owned", count: 21, visible: :all
    assert_no_selector ".collection-grid .collection-slot__copies", visible: :all
    assert appended.none? { |href| held_paths.any? { URI(href).path.start_with?(it) } }
    assert_selector "#collection-results-status", text: "Cards 61 to 81 of 81 shown.", visible: :all
    assert_no_selector "#collection-pages a[rel=next]", visible: :all
    assert_selector "#collection-pages a[rel=prev][href*='state%5B%5D=missing']", visible: :all
    assert_selector "#collection-pages [aria-current=page]", text: "2", visible: :all
    assert_current_path library_cards_path(locale: :en, **filters)
  end

  test "the whole grid in French appends its pages one after the other, to its last card" do
    visit library_cards_path(locale: :fr)
    assert_slots 60

    scroll_to_pages
    assert_slots 120
    assert_selector "#collection-results-status", text: "Cartes 61 à 120 sur 150 affichées.", visible: :all

    scroll_to_pages
    assert_slots 150
    assert_selector "#collection-results-status", text: "Cartes 121 à 150 sur 150 affichées.", visible: :all
    assert_selector "#collection-pages [aria-current=page]", text: "3", visible: :all
    assert_no_selector "#collection-pages a[rel=next]", visible: :all
  end

  test "the grid is one tab stop: arrow keys move the focus by card and by row, into appended pages, End reaches the last card" do
    visit library_cards_path(locale: :en)
    assert_slots 60
    assert_selector ".collection-grid a.card-link[tabindex='0']", count: 1, visible: :all
    columns = evaluate_script("[...document.querySelectorAll('.collection-grid > li')].filter((slot, _, slots) => slot.getBoundingClientRect().top === slots[0].getBoundingClientRect().top).length")

    find(".collection-grid > li:first-child a.card-link").execute_script("this.focus()")
    page.send_keys(:right)
    assert_focused ".collection-grid > li:nth-child(2) a.card-link"
    page.send_keys(:down)
    assert_focused ".collection-grid > li:nth-child(#{2 + columns}) a.card-link"

    scroll_to_pages
    assert_slots 120
    assert_no_selector ".collection-grid a.card-link:not([tabindex])", visible: :all
    assert_selector ".collection-grid a.card-link[tabindex='0']", count: 1, visible: :all
    find(".collection-grid > li:nth-child(60) a.card-link").execute_script("this.focus()")
    page.send_keys(:down)
    assert_focused ".collection-grid > li:nth-child(#{60 + columns}) a.card-link"
    page.send_keys(:end)
    assert_focused ".collection-grid > li:nth-child(120) a.card-link"
    page.send_keys(:tab)
    eventually("the focus stayed in the grid") { evaluate_script("!document.activeElement?.closest('.collection-grid')") }
  end

  test "back from a card of an appended page, the grid shows its appended cards at its scroll, the focus on that card's link" do
    visit library_cards_path(locale: :en)
    scroll_to_pages
    assert_slots 120

    slot = find(".collection-grid > li:nth-child(61) a.card-link")
    slot.execute_script("this.scrollIntoView({ block: 'center' })")
    grid_scroll = scroll_y
    slot.click
    assert_selector ".card-detail h1"
    assert_no_selector "html[aria-busy]", visible: :all

    go_back

    assert_current_path library_cards_path(locale: :en)
    assert_selector ".collection-grid > li:nth-child(120)", visible: :all
    assert_scrolled_to grid_scroll
    assert_focused ".collection-grid > li:nth-child(61) a.card-link"
  end

  private
    # A count assertion over the grid reads every slot it found, one round
    # trip each, to check its visibility or to word a failed attempt's
    # message: over a hundred slots one attempt outlasts the wait, before
    # the page appended or the frame reloaded lands. The last slot and the
    # absence of the next one each read one node at most.
    def assert_slots(count)
      assert_selector ".collection-grid > li:nth-child(#{count})", visible: :all
      assert_no_selector ".collection-grid > li:nth-child(#{count + 1})", visible: :all
    end

    def scroll_to_pages
      find("#collection-pages").execute_script("this.scrollIntoView({ block: 'end' })")
    end

    def scroll_y = evaluate_script("window.scrollY")

    def assert_scrolled_to(y)
      eventually("scrolled to #{scroll_y}, not #{y}") { (scroll_y - y).abs <= 2 }
    end

    def assert_focused(selector)
      eventually("the focus is not on #{selector}") { evaluate_script("document.activeElement?.matches(#{selector.to_json})") }
    end

    # The watermark the page posted, waited for (the POST runs after the
    # page has rendered).
    def wait_for_watermark
      page.document.synchronize do
        Game::PlayerState.find_by!(player_id: @player.id).collection_seen_up_to || raise(Capybara::ElementNotFound, "the watermark is not posted yet")
      end
    end
end
