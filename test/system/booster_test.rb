require "application_system_test_case"
require_relative "../support/game_packs"

# The booster screen (stories 8.11 and 8.12; EXPERIENCE.md: Booster,
# Opening protocol): the canister sends the opening exchange and deals the
# cards face down; one activation reveals a card, "Reveal all" the rest;
# the top bar's rarity counter rises at each reveal and its reserve chip
# follows each answer; every refusal leaves the canister at rest and says
# why. On a phone the cards land in a pile, each revealed card is stored in
# the tray (Store, a tap or a swipe) and a filled slot opens the card zoom;
# from 720 to 899px the row deals small cards; a width crossing a
# breakpoint draws the same hand again. Reduced motion is emulated in every
# test but those named "with motion" and the loop budget's.
class BoosterTest < ApplicationSystemTestCase
  include GamePacks

  PHONE = [ 390, 844 ].freeze

  setup do
    @player = accounts_players(:player)
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:steam] = OmniAuth::AuthHash.new(provider: "steam", uid: "https://steamcommunity.com/openid/id/#{@player.steam_id}")
    reduce_motion(true)
    visit home_path(locale: :en)
    click_steam_sign_in
    assert_signed_in
  end

  teardown do
    reduce_motion(false)
    OmniAuth.config.mock_auth.delete(:steam)
    OmniAuth.config.test_mode = false
    page.driver.browser.manage.window.resize_to(*SCREEN_SIZE)
  end

  def reduce_motion(on)
    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", features: [ { name: "prefers-reduced-motion", value: on ? "reduce" : "" } ])
  end

  def card_ids(*names)
    names.map { |name| catalog_card_seasons(name).id }
  end

  # Packs holding these card-seasons, then the booster screen with its
  # island drawn. `more` leaves another pack available after them.
  def open_screen(*packs, kind: :regular, more: false)
    packs.each_with_index { |cards, index| create_pack(@player, cards:, kind:, available_at: (packs.size - index).days.ago) }
    create_pack(@player, available_at: 1.hour.ago) if more
    visit booster_path(locale: :en)
    assert_selector ".booster"
    record_requests
  end

  # Every opening request's key, in order, kept by a wrapper around fetch.
  def record_requests
    page.execute_script(<<~JS)
      window.boosterKeys = []
      const realFetch = window.fetch
      window.fetch = (url, init) => {
        window.boosterKeys.push(init && init.headers && init.headers["Idempotency-Key"])
        return realFetch(url, init)
      }
    JS
  end

  def request_keys
    page.evaluate_script("window.boosterKeys")
  end

  def card(position)
    ".booster-card:nth-child(#{position})"
  end

  def hit(position)
    "#{card(position)} .booster-card__hit"
  end

  def open_canister
    find(".booster-canister").click
  end

  def assert_dealt(count)
    assert_selector ".booster-card[data-dealt]", count:, wait: 10
    assert_selector ".booster__state", text: /\AINVENTORY\z/
  end

  def state
    find(".booster__state-word").text
  end

  def assert_announced(text, wait: Capybara.default_max_wait_time)
    assert_selector ".booster [role=status] > span:last-child", text:, exact_text: true, visible: :all, wait:
  end

  def announcements
    all(".booster [role=status] > span", visible: :all).map { it.text(:all) }
  end

  def focused?(selector)
    page.evaluate_script("document.activeElement.matches(#{selector.to_json})")
  end

  def assert_focus(selector, message = "focus should be on #{selector}")
    page.document.synchronize do
      raise Capybara::ExpectationNotMet, message unless focused?(selector)
    end
  end

  def rarity_count(tier)
    find(".top-bar .rarity-counter__count[data-tier=#{tier}]").text
  end

  def revealed_at(position)
    Float(find(card(position))["data-revealed-at"])
  end

  def opened_packs
    Game::Pack.where(player_id: @player.id).where.not(opened_at: nil).count
  end

  test "menu 01 leads to the screen: the canister, the information panel and the booster top bar" do
    3.times { |index| create_pack(@player, available_at: (index + 1).hours.ago) }
    visit home_path(locale: :en)
    find(".hub-menu .menu-item[aria-keyshortcuts='1']").click

    assert_current_path "/en/booster"
    assert_selector ".booster-canister[aria-label='Open the booster Season 1, grand catalogue, 5 cards']"
    assert_selector ".booster__canister-hint", text: "CLICK TO OPEN"
    within(".booster__info") do
      assert_selector ".booster__kicker", text: "BOOSTER · SEASON 1"
      assert_selector ".booster__title", text: "GRAND CATALOGUE"
      assert_selector ".booster__row", text: /CARDS PER BOOSTER\s+5/
      assert_selector ".booster__row", text: /IN RESERVE\s+3 BOOSTERS/
      assert_selector ".booster__state", text: "SEALED"
      assert_selector ".booster__pip[data-lit]", count: 3
      assert_selector ".booster__pip", count: 10
      assert_button "Open the booster"
      assert_button "Reveal all", disabled: true
      assert_link "Back to the bridge", href: "/en"
      assert_selector ".booster__counter", text: "Cards revealed: — / 5"
    end
    assert_focus ".booster__open"
    assert_no_selector ".booster__fallback", visible: true
    within(".top-bar") do
      assert_selector ".rarity-counter__button"
      assert_selector ".packs-chip--static", text: /3\s+IN RESERVE/
      assert_no_selector "a.packs-chip"
    end
  end

  test "the packs chip leads to the screen" do
    create_pack(@player)
    visit home_path(locale: :en)
    find(".top-bar a.packs-chip").click

    assert_current_path "/en/booster"
    assert_selector ".booster-canister"
  end

  test "an opening deals the cards face down; each reveal shows its card, says it, and raises the top bar's count then" do
    open_screen(card_ids(:common_card_one, :uncommon_card_one, :rare_card_one, :portal_one, :common_card_one), more: true)
    commons = Integer(rarity_count("common"))

    open_canister
    assert_dealt(5)

    assert_equal 1, request_keys.size
    assert_match(/\A\h{8}-\h{4}-4\h{3}-[89ab]\h{3}-\h{12}\z/, request_keys.first)
    assert_selector ".booster-card:not([data-revealed])", count: 5
    assert_selector ".booster-card__back.booster-card__back--standard", count: 5
    assert_selector "#{card(1)} .booster-card__label", text: "? ? ?"
    assert_equal "Card 1 of 5, face down. Reveal.", find(hit(1))["aria-label"]
    assert_focus hit(1)
    # The reserve follows the answer; the counts wait for the reveals.
    assert_selector ".top-bar .packs-chip--static .packs-chip__count", text: "1"
    assert_selector ".booster__pip[data-lit]", count: 1
    assert_equal commons, Integer(rarity_count("common"))
    assert_selector ".booster__counter", text: "Cards revealed: 0 / 5"
    assert_selector ".booster__hint", text: "Click a card to reveal it · 5 left"
    assert_button "Open the next one", disabled: true

    page.send_keys(:enter)
    assert_selector "#{card(1)}[data-revealed]"
    assert_selector "#{card(1)} .booster-card__label", text: "COMMON"
    assert_announced "Card 1: Tin Soldier — 2024. Common."
    assert_equal commons + 1, Integer(rarity_count("common"))
    assert_equal "Tin Soldier — 2024, Common. See the card.", find(hit(1))["aria-label"]
    assert_selector ".booster__counter", text: "Cards revealed: 1 / 5"
    assert_focus hit(1)

    find(hit(4)).click
    assert_selector "#{card(4)}[data-revealed] .booster-card__label", text: "EPIC"
    assert_announced "Card 4: Portal — Valve, 2007. Epic."
    assert_equal commons + 1, Integer(rarity_count("common"))
    assert_selector "#{card(4)} .booster-card__front .card.card--m.card--booster.card--rarity-epic"
  end

  test "a revealed card ignores activation for 400 ms, then opens its card page" do
    open_screen(card_ids(*[ :rare_card_one ] * 5))
    open_canister
    assert_dealt(5)

    find(hit(2)).click
    assert_selector "#{card(2)}[data-revealed]"
    # Within the guard: the face's click stays on the screen.
    page.execute_script("document.querySelector(#{"#{card(2)} .booster-card__front .card".to_json}).click()")
    assert_current_path "/en/booster"

    sleep 0.5
    find("#{card(2)} .booster-card__front .card").click
    assert_current_path "/en/cards/blue-depths"
  end

  test "Reveal all reveals the rest in order, holds the Légendaire, announces once and focuses the next booster" do
    open_screen(card_ids(:common_card_one, :legendary_card_one, :common_card_one, :uncommon_card_one, :rare_card_one), more: true)
    open_canister
    assert_dealt(5)
    find(hit(1)).click
    assert_announced "Card 1: Tin Soldier — 2024. Common."

    click_on "Reveal all"
    assert_button "Reveal all", disabled: true
    # Input on the cards is ignored while it runs.
    page.execute_script("document.querySelector(#{hit(5).to_json}).click()")

    assert_selector ".booster-card[data-revealed]", count: 5, wait: 15
    assert_announced "4 cards revealed: Legendary × 1, Rare × 1, Uncommon × 1, Common × 1.", wait: 10
    assert_operator revealed_at(3) - revealed_at(2), :>=, 1400
    assert_operator revealed_at(5) - revealed_at(4), :>=, 180
    assert_operator revealed_at(4) - revealed_at(3), :<, 1400
    assert_includes announcements, "Legendary signal"
    assert_selector ".booster__state", text: "INVENTORY COMPLETE"
    assert_selector ".booster__hint", text: "Booster inventoried · +5 cards in the collection"
    assert_selector "#{card(2)} .booster-card__label", text: "LEGENDARY!"
    assert_focus ".booster__open"
    assert_button "Open the next one"
  end

  test "with motion: the canister blows, the cards fly in, and a Légendaire plays its whole sequence" do
    reduce_motion(false)
    open_screen(card_ids(:legendary_card_one, :common_card_one, :common_card_one, :common_card_one, :common_card_one))

    open_canister
    assert_selector ".booster__state", text: /ARMING|EJECTION|INVENTORY/
    assert_dealt(5)
    assert_no_selector ".booster-canister"

    started = page.evaluate_script("performance.now()")
    find(hit(1)).click
    assert_selector ".booster__stage[data-legendary]"
    assert_selector ".booster__state", text: "LEGENDARY SIGNAL"
    assert_selector ".booster__state[data-tone=gold]"
    assert_announced "Legendary signal"
    assert_selector ".booster__banner--large", text: "LEGENDARY!", wait: 3
    assert_selector ".booster__banner-line", text: "Golden Crown · 1998"
    assert_announced "Card 1: Golden Crown — 1998. Legendary."
    assert_no_selector ".booster__stage[data-legendary]", wait: 5
    assert_selector ".booster__state", text: /\AINVENTORY\z/
    # Jump and charge, then the spin: the card shows itself after both began.
    assert_operator revealed_at(1) - started, :>=, 614 + 106
    assert_selector "#{card(1)} .booster-card__flip.is-up"
    assert_equal "1", page.evaluate_script("getComputedStyle(document.querySelector(#{"#{card(1)} .booster-card__rays".to_json})).opacity")
  end

  test "the next booster: the cards sink, a canister docks and opens with a new key; at zero the button says the reserve is empty" do
    open_screen(card_ids(*[ :common_card_one ] * 5), card_ids(*[ :uncommon_card_one ] * 5))
    open_canister
    assert_dealt(5)
    click_on "Reveal all"
    assert_selector ".booster-card[data-revealed]", count: 5, wait: 10
    # The last reveal over, the button takes activation.
    assert_selector ".booster__state", text: "INVENTORY COMPLETE"
    assert_selector ".booster__open:not([disabled]):not([aria-disabled])"

    click_on "Open the next one"
    assert_selector ".booster-card[data-tier=uncommon][data-dealt]", count: 5, wait: 10
    assert_selector ".booster-card[data-tier=common]", count: 0
    assert_equal 2, request_keys.uniq.size
    assert_equal 2, opened_packs

    click_on "Reveal all"
    assert_selector ".booster-card[data-revealed]", count: 5, wait: 10
    assert_button "Reserve empty", disabled: true
    assert_focus ".booster__back"
    assert_selector ".top-bar .packs-chip--static .packs-chip__count", text: "0"
  end

  test "a daily bonus pack deals and counts three cards" do
    open_screen(card_ids(:rare_card_one, :portal_one, :legendary_card_one), kind: :bonus)
    open_canister

    assert_dealt(3)
    assert_selector ".booster__counter", text: "Cards revealed: 0 / 3"
    assert_selector ".booster__hint", text: "Click a card to reveal it · 3 left"
    assert_equal "Card 3 of 3, face down. Reveal.", find(hit(3))["aria-label"]
  end

  test "an empty reserve shows when the next booster comes, the button disabled and the focus on the way back" do
    create_pack(@player, available_at: 2.hours.from_now)
    visit booster_path(locale: :en)

    assert_selector ".booster__empty", text: /RESERVE EMPTY/
    assert_selector ".booster__empty-next", text: /Next booster in 1:59:\d\d|Next booster in 2:00:00/
    assert_no_selector ".booster-canister"
    assert_button "Reserve empty", disabled: true
    assert_selector ".booster__state", text: "WAITING"
    assert_focus ".booster__back"
  end

  test "an empty reserve whose next booster arrives while the screen shows: the screen refreshes and the booster can be opened" do
    create_pack(@player, available_at: 2.seconds.from_now)
    visit booster_path(locale: :en)
    assert_selector ".booster__empty"
    assert_button "Reserve empty", disabled: true

    assert_selector ".booster-canister", wait: 10
    assert_button "Open the booster", disabled: false
    assert_selector ".booster__state", text: "SEALED"
    assert_selector ".top-bar .packs-chip--static .packs-chip__count", text: "1"
  end

  test "a refusal (the reserve emptied elsewhere) deals nothing and says why, inline, in a toast and aloud" do
    open_screen(card_ids(*[ :common_card_one ] * 5))
    Game::OpenPack.new.call(player: @player).value!
    message = I18n.t("errors.game.no_pack_available", locale: :en)

    open_canister

    assert_selector ".booster__reason", text: message
    assert_selector ".toasts .toast--alert", text: /OPENING CANCELLED.*#{Regexp.escape(message)}/m
    assert_announced message
    assert_selector ".booster__state", text: "WAITING"
    assert_selector ".booster__empty"
    assert_no_selector ".booster-card"
    assert_button "Reserve empty", disabled: true
    assert_selector ".top-bar .packs-chip--static .packs-chip__count", text: "0"
    assert_equal 1, request_keys.size
    assert_equal 1, opened_packs
  end

  test "a throttled opening leaves the canister sealed and keeps its key for the next activation" do
    open_screen(card_ids(*[ :common_card_one ] * 5))
    page.execute_script(<<~JS)
      const recordingFetch = window.fetch
      let first = true
      window.fetch = (url, init) => {
        if (!first) return recordingFetch(url, init)
        first = false
        window.boosterKeys.push(init.headers["Idempotency-Key"])
        const body = JSON.stringify({ error: { code: "throttled", message: "Too many openings in a minute. Try again in a moment." } })
        return Promise.resolve(new Response(body, { status: 429, headers: { "Content-Type": "application/json" } }))
      }
    JS

    open_canister
    assert_selector ".booster__reason", text: "Too many openings in a minute. Try again in a moment."
    assert_selector ".toasts .toast--alert", text: /Too many openings/
    assert_selector ".booster__state", text: "SEALED"
    assert_selector ".booster-canister:not([aria-disabled])"
    assert_equal 0, opened_packs

    open_canister
    assert_dealt(5)
    assert_no_selector ".booster__reason"
    assert_equal 2, request_keys.size
    assert_equal 1, request_keys.uniq.size
  end

  test "a lost answer: the next activation sends the same key and gets the same pack, nothing more opened" do
    open_screen(card_ids(*[ :rare_card_one ] * 5), card_ids(*[ :common_card_one ] * 5))
    page.execute_script(<<~JS)
      const recordingFetch = window.fetch
      let first = true
      window.fetch = async (url, init) => {
        const response = await recordingFetch(url, init)
        if (!first) return response
        first = false
        await response.text()
        throw new TypeError("Failed to fetch")
      }
    JS

    open_canister
    assert_selector ".booster__reason", text: I18n.t("boosters.island.failed", locale: :en)
    assert_selector ".toasts .toast--alert", text: /OPENING CANCELLED/
    assert_selector ".booster__state", text: "SEALED"
    assert_no_selector ".booster-card"
    assert_equal 1, opened_packs

    open_canister
    assert_dealt(5)
    assert_selector ".booster-card[data-tier=rare]", count: 5
    assert_equal 2, request_keys.size
    assert_equal 1, request_keys.uniq.size
    assert_equal 1, opened_packs
  end

  test "a stale CSRF token: Rails' HTML refusal reads as the generic reason, nothing opens, the key is kept" do
    create_pack(@player, cards: card_ids(*[ :common_card_one ] * 5))
    ActionController::Base.allow_forgery_protection = true
    visit booster_path(locale: :en)
    assert_selector ".booster"
    record_requests
    token = page.evaluate_script("document.querySelector('meta[name=csrf-token]').content")
    assert_predicate token, :present?
    page.execute_script("document.querySelector('meta[name=csrf-token]').content = 'stale'")

    open_canister
    assert_selector ".booster__reason", text: I18n.t("boosters.island.failed", locale: :en)
    assert_selector ".booster__state", text: "SEALED"
    assert_equal 0, opened_packs

    page.execute_script("document.querySelector('meta[name=csrf-token]').content = #{token.to_json}")
    open_canister
    assert_dealt(5)
    assert_equal 1, request_keys.uniq.size
    assert_equal 1, opened_packs
  ensure
    ActionController::Base.allow_forgery_protection = false
  end

  test "the top bar's back button is locked while the opening runs and during a reveal, then unlocked" do
    open_screen(card_ids(:legendary_card_one, *[ :common_card_one ] * 4))
    page.execute_script(<<~JS)
      const recordingFetch = window.fetch
      window.fetch = (url, init) => new Promise((resolve) => setTimeout(() => resolve(recordingFetch(url, init)), 1500))
    JS
    back = ".top-bar .top-bar__start a.button"
    assert_no_selector "#{back}[aria-disabled]"

    open_canister
    assert_selector "#{back}[aria-disabled=true][data-navigation-locked]"
    assert_selector ".booster__back[aria-disabled=true]"
    find(back).click
    assert_current_path "/en/booster"
    find(".booster__back").click
    assert_current_path "/en/booster"
    assert_dealt(5)
    assert_no_selector "#{back}[aria-disabled]"

    # A Légendaire's still banner holds the lock 1.4 s under reduced motion.
    find(hit(1)).click
    assert_selector "#{back}[aria-disabled=true]"
    assert_no_selector "#{back}[aria-disabled]", wait: 5
    assert_selector ".booster__back:not([aria-disabled])"
  end

  test "a reveal waiting for its art locks the navigation at once, and a Légendaire waiting holds every other activation" do
    open_screen(card_ids(:legendary_card_one, *[ :common_card_one ] * 4))
    open_canister
    assert_dealt(5)
    # The Légendaire's art is not drawn yet: its reveal waits for it.
    art = "#{card(1)} .booster-card__front .card__art"
    assert_selector "#{art}[data-art]", visible: :all
    page.execute_script("document.querySelector(#{art.to_json}).removeAttribute('data-art')")
    back = ".top-bar .top-bar__start a.button"

    find(hit(1)).click
    assert_selector "#{back}[aria-disabled=true]"
    assert_selector ".booster__back[aria-disabled=true]"
    page.execute_script("document.querySelector(#{hit(2).to_json}).click()")
    click_on "Reveal all"
    sleep 0.5
    assert_no_selector ".booster-card[data-revealed]"

    page.execute_script("document.querySelector(#{art.to_json}).setAttribute('data-art', 'drawn')")
    assert_selector "#{card(1)}[data-revealed]"
    assert_no_selector "#{back}[aria-disabled]", wait: 5
    assert_selector ".booster-card[data-revealed]", count: 1
  end

  test "with reduced motion nothing loops or bursts, and a Légendaire holds a still banner under its signal" do
    open_screen(card_ids(:legendary_card_one, *[ :common_card_one ] * 4))
    %w[.booster-canister__idle .booster-canister__rays].each do |selector|
      assert_equal "none", page.evaluate_script("getComputedStyle(document.querySelector(#{selector.to_json})).animationName")
    end
    page.execute_script(<<~JS)
      window.boosterFx = 0
      new MutationObserver((records) => {
        for (const record of records) for (const node of record.addedNodes) {
          if (node instanceof Element && /booster-fx__/.test(node.className)) window.boosterFx += 1
        }
      }).observe(document.querySelector(".booster"), { childList: true, subtree: true })
    JS

    open_canister
    assert_dealt(5)
    find(hit(1)).click
    assert_selector ".booster__state", text: "LEGENDARY SIGNAL"
    assert_selector ".booster__banner--large", text: "LEGENDARY!"
    assert_selector ".booster__banner-line", text: "Golden Crown · 1998"
    assert_no_selector ".booster__stage[data-legendary]"
    assert_selector ".booster__state", text: /\AINVENTORY\z/, wait: 5
    assert_equal 0, page.evaluate_script("window.boosterFx")
    assert_no_selector "#{card(1)} .booster-card__rays", visible: true
  end

  test "leaving during Reveal all stops the island: the hub's counts and links stay as they were" do
    create_pack(@player, cards: card_ids(:legendary_card_one, *[ :common_card_one ] * 4))
    # Reached through Turbo, so Back is a restoration visit in the same window.
    visit home_path(locale: :en)
    find(".hub-menu .menu-item[aria-keyshortcuts='1']").click
    assert_current_path "/en/booster"
    open_canister
    assert_dealt(5)

    click_on "Reveal all"
    assert_selector "#{card(1)}[data-revealed]"
    page.go_back
    assert_current_path "/en"
    assert_no_selector ".booster"
    commons = rarity_count("common")
    page.execute_script(<<~JS)
      window.lateBoosterEvents = []
      for (const name of ["gameble:tier-revealed", "gameble:navigation-locked"]) {
        addEventListener(name, (event) => window.lateBoosterEvents.push([name, event.detail]))
      }
    JS
    # The Légendaire's still banner held 1.4 s; the next reveals would have run since.
    sleep 3

    assert_equal [], page.evaluate_script("window.lateBoosterEvents")
    assert_equal commons, rarity_count("common")
    assert_no_selector "[data-navigation-locked]", visible: :all
  end

  test "a sealed canister whose next booster arrives while the screen shows: the screen refreshes with one more in reserve" do
    create_pack(@player, available_at: 1.hour.ago)
    create_pack(@player, available_at: 3.seconds.from_now)
    visit booster_path(locale: :en)
    assert_selector ".booster__row", text: /IN RESERVE\s+1 BOOSTER\z/
    page.execute_script("document.querySelector('.booster').dataset.marker = 'before'")

    assert_selector ".booster__row", text: /IN RESERVE\s+2 BOOSTERS/, wait: 10
    assert_no_selector ".booster[data-marker]"
    assert_selector ".booster__state", text: "SEALED"
    assert_selector ".top-bar .packs-chip--static .packs-chip__count", text: "2"
  end

  test "the countdown reaching zero while cards are dealt leaves the screen as it is" do
    create_pack(@player, cards: card_ids(*[ :common_card_one ] * 5), available_at: 1.hour.ago)
    arrives = 4.seconds.from_now
    create_pack(@player, available_at: arrives)
    visit booster_path(locale: :en)
    open_canister
    assert_dealt(5)
    page.execute_script("document.querySelector('.booster').dataset.marker = 'kept'")

    sleep [ arrives + 2.seconds - Time.current, 0 ].max
    assert_selector ".booster[data-marker=kept]"
    assert_selector ".booster-card[data-dealt]", count: 5
    assert_selector ".booster__state", text: /\AINVENTORY\z/
  end

  test "an island whose code does not load leaves a message and a reload of the whole page" do
    page.driver.browser.execute_cdp("Network.enable")
    page.driver.browser.execute_cdp("Network.setBlockedURLs", urls: [ "*/Booster-*.js" ])
    create_pack(@player)
    visit booster_path(locale: :en)

    assert_selector ".booster--failed[role=alert]", text: I18n.t("boosters.island.island_failed", locale: :en)
    assert_no_selector ".booster-canister"
    # The form without JavaScript stays, a way to open the booster all the same.
    assert_selector ".booster__fallback", text: /OPEN THE BOOSTER/
    reload = find_link(I18n.t("boosters.island.reload", locale: :en), href: "/en/booster")
    assert_equal "false", reload["data-turbo"]

    page.driver.browser.execute_cdp("Network.setBlockedURLs", urls: [])
    reload.click
    assert_selector ".booster-canister"
  ensure
    page.driver.browser.execute_cdp("Network.setBlockedURLs", urls: [])
    page.driver.browser.execute_cdp("Network.disable")
  end

  # ---- The phone, the narrow row and the rebuild (story 8.12) ----

  def phone_card(position)
    ".booster-card[data-position='#{position}']"
  end

  def phone_hit(position)
    "#{phone_card(position)} .booster-card__hit"
  end

  def on_phone
    page.driver.browser.manage.window.resize_to(*PHONE)
  end

  # The phone's pile dealt: every card at card-xl, the first on top with the focus.
  def assert_pile(count)
    assert_selector ".booster[data-layout=phone] .booster__pile .booster-card[data-dealt]", count:, wait: 10
    assert_selector ".booster__state", text: /\AINVENTORY\z/
  end

  def boxes_apart?(first, second)
    page.evaluate_script(<<~JS)
      (() => {
        const a = document.querySelector(#{first.to_json}).getBoundingClientRect()
        const b = document.querySelector(#{second.to_json}).getBoundingClientRect()
        return a.bottom <= b.top || b.bottom <= a.top || a.right <= b.left || b.right <= a.left
      })()
    JS
  end

  # A drag of the top card by synthetic touch pointer events (pointerId 7),
  # as a finger would: down, halfway, up at (dx, dy).
  def drag_top(position, dx, dy)
    execute_script(<<~JS, dx, dy)
      const face = document.querySelector(#{"#{phone_card(position)} .booster-card__front .card".to_json})
      const box = document.querySelector(#{"#{phone_card(position)} .booster-card__frame".to_json}).getBoundingClientRect()
      const x = box.left + box.width / 2, y = box.top + box.height / 2
      const event = (type, clientX, clientY) => new PointerEvent(type, { bubbles: true, pointerId: 7, pointerType: "touch", isPrimary: true, clientX, clientY })
      face.dispatchEvent(event("pointerdown", x, y))
      face.dispatchEvent(event("pointermove", x + arguments[0] / 2, y + arguments[1] / 2))
      face.dispatchEvent(event("pointerup", x + arguments[0], y + arguments[1]))
    JS
  end

  # Running infinite animations on the page (AD-27: six at most on a phone view).
  def infinite_loops
    page.evaluate_script(<<~JS)
      document.getAnimations().filter((animation) => animation.playState === "running" && animation.effect.getTiming().iterations === Infinity).length
    JS
  end

  def filled_slots
    all(".booster-tray__slot--filled").size
  end

  test "on a phone: a pile of large cards, one at a time, each revealed then stored by Store, a tap or a swipe, the focus following" do
    on_phone
    open_screen(card_ids(:common_card_one, :uncommon_card_one, :rare_card_one, :portal_one, :common_card_one), more: true)

    within(".booster-strip") do
      assert_selector "h2#booster-title", text: "SEASON 1 · GRAND CATALOGUE"
      assert_selector ".booster__pip[data-lit]", count: 2
      assert_selector ".booster__state", text: "SEALED"
    end
    assert_selector ".booster__canister-hint", text: "TAP TO OPEN"
    assert_selector ".booster__canister-facts", text: "5 cards"
    assert_no_selector ".booster__info"
    assert_no_selector ".booster__counter"
    assert_button "Open the booster"
    assert_button "Reveal all", disabled: true

    open_canister
    assert_pile(5)
    assert_selector ".booster__pile .booster-card__front .card.card--xl", count: 5, visible: :all
    assert_selector "#{phone_card(1)}[data-top]"
    assert_selector ".booster__pile .booster-card[inert]", count: 4
    assert_focus phone_hit(1)
    assert_selector ".booster-tray__slot", count: 5
    assert_selector ".booster-tray__slot[data-next]", count: 1
    assert_selector ".booster-tray__count", text: %r{CARD\s+0 / 5}
    assert_selector ".booster-plate-band__hint", text: "Tap the card to reveal it"
    assert_no_selector ".booster-plate"

    # One activation reveals the top card; the plate tells it, under the card.
    page.send_keys(:enter)
    assert_selector "#{phone_card(1)}[data-revealed]"
    assert_selector ".booster-plate[data-tier=common]", text: /COMMON.*TIN SOLDIER · 2024/m
    assert_announced "Card 1: Tin Soldier — 2024. Common."
    assert_equal "Tin Soldier — 2024, Common. Store the card.", find(phone_hit(1))["aria-label"]
    assert_focus phone_hit(1)
    assert boxes_apart?(".booster-plate", "#{phone_card(1)} .booster-card__frame"), "the plate should never cover the card"
    sleep 0.45
    click_on "Store"
    assert_no_selector phone_card(1)
    assert_selector ".booster-tray__slot--filled[data-tier=common]", count: 1
    assert_selector ".booster-tray__count", text: %r{CARD\s+1 / 5}
    assert_focus phone_hit(2)

    # The second: a tap once its guard is over (a tap within it does nothing).
    page.send_keys(:enter)
    assert_selector "#{phone_card(2)}[data-revealed]"
    find("#{phone_card(2)} .booster-card__front .card").click
    assert_selector phone_card(2)
    sleep 0.45
    find("#{phone_card(2)} .booster-card__front .card").click
    assert_no_selector phone_card(2)
    assert_equal 2, filled_slots
    assert_focus phone_hit(3)

    # The third: a swipe; a short drag first springs back.
    page.send_keys(:enter)
    assert_selector "#{phone_card(3)}[data-revealed]"
    sleep 0.45
    drag_top(3, 30, 20)
    sleep 0.3
    assert_selector "#{phone_card(3)}[data-revealed][data-top]"
    assert_equal 2, filled_slots
    assert_equal "", find("#{phone_card(3)} .booster-card__float", visible: :all).evaluate_script("this.style.transform")
    drag_top(3, 120, 10)
    assert_no_selector phone_card(3)
    assert_selector ".booster-tray__count", text: %r{CARD\s+3 / 5}
    assert_focus phone_hit(4)

    page.send_keys(:enter)
    assert_selector ".booster-plate[data-tier=epic]", text: /EPIC.*PORTAL · 2007/m
    sleep 0.45
    click_on "Store"
    assert_focus phone_hit(5)
    page.send_keys(:enter)
    assert_selector "#{phone_card(5)}[data-revealed]"
    sleep 0.45
    click_on "Store"

    assert_equal 5, filled_slots
    assert_no_selector ".booster__pile .booster-card"
    assert_selector ".booster__state", text: "INVENTORY COMPLETE"
    assert_selector ".booster-plate-band__hint", text: "Booster inventoried · +5 cards in the collection"
    assert_focus ".booster__open"
    assert_button "Open the next one"
    assert page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth"), "the page should not scroll sideways"
  end

  test "on a phone a filled tray slot opens the card zoom; Esc gives the focus back to the slot, See the card leads to its page" do
    on_phone
    open_screen(card_ids(*[ :rare_card_one ] * 5))
    open_canister
    assert_pile(5)
    page.send_keys(:enter)
    assert_selector "#{phone_card(1)}[data-revealed]"
    sleep 0.45
    click_on "Store"
    slot = ".booster-tray__slot--filled"
    assert_equal "Blue Depths — 2014, Rare. Enlarge.", find(slot)["aria-label"]

    find(slot).click
    within("dialog.booster-zoom[open]") do
      assert_selector "h2", text: "BLUE DEPTHS"
      assert_selector ".booster-zoom__line", text: "RARE · 2014"
      assert_selector ".booster-zoom__face .card.card--xl.card--rarity-rare", visible: :all
      assert_link "See the card"
      assert_button "Close"
      assert_selector ".booster-zoom__tip", text: "Hold the card to tilt it"
    end
    assert_equal "booster-zoom-title", find("dialog.booster-zoom")["aria-labelledby"]

    page.send_keys(:escape)
    assert_no_selector "dialog.booster-zoom"
    assert_focus slot
    assert_current_path "/en/booster"

    find(slot).click
    click_on "Close"
    assert_no_selector "dialog.booster-zoom"
    assert_focus slot

    find(slot).click
    click_on "See the card"
    assert_current_path "/en/cards/blue-depths"
  end

  test "on a phone Reveal all reveals and stores every card in the tray, with one summary" do
    on_phone
    open_screen(card_ids(:common_card_one, :legendary_card_one, :common_card_one, :uncommon_card_one, :rare_card_one), more: true)
    open_canister
    assert_pile(5)

    click_on "Reveal all"
    assert_selector ".booster-tray__slot--filled", count: 5, wait: 20
    assert_announced "5 cards revealed: Legendary × 1, Rare × 1, Uncommon × 1, Common × 2.", wait: 10
    assert_equal 1, announcements.count { it.end_with?("cards revealed: Legendary × 1, Rare × 1, Uncommon × 1, Common × 2.") }
    assert_includes announcements, "Legendary signal"
    assert_no_selector ".booster__pile .booster-card"
    assert_selector ".booster__state", text: "INVENTORY COMPLETE"
    assert_focus ".booster__open"

    # The next booster: the tray clears, a canister docks and opens with a new key.
    click_on "Open the next one"
    assert_pile(5)
    assert_selector ".booster-tray__slot--filled", count: 0
    assert_selector ".booster-tray__count", text: %r{CARD\s+0 / 5}
    assert_focus phone_hit(1)
    assert_equal 2, request_keys.uniq.size
  end

  test "with motion on a phone a Légendaire plays in the caption plate, never over the card, under its signal" do
    reduce_motion(false)
    on_phone
    open_screen(card_ids(:legendary_card_one, *[ :common_card_one ] * 4))
    open_canister
    assert_pile(5)

    find(phone_hit(1)).click
    assert_selector ".booster__state", text: "LEGENDARY SIGNAL"
    assert_selector ".booster-plate[data-tier=legendary]", text: /LEGENDARY!.*GOLDEN CROWN · 1998/m, wait: 3
    assert_selector ".booster__state", text: "LEGENDARY SIGNAL"
    assert_no_selector ".booster__banner"
    assert boxes_apart?(".booster-plate", "#{phone_card(1)} .booster-card__frame"), "the plate should never cover the card"
    assert_selector ".booster__state", text: /\AINVENTORY\z/, wait: 5
    assert_no_selector ".booster__banner"
  end

  test "with motion on a phone a finger held still tilts the revealed card: neither dragged nor stored" do
    reduce_motion(false)
    on_phone
    open_screen(card_ids(*[ :common_card_one ] * 5))
    open_canister
    assert_pile(5)
    find(phone_hit(1)).click
    assert_selector "#{phone_card(1)}[data-revealed]"
    assert_no_selector ".booster__back[aria-disabled=true]", wait: 5
    sleep 0.45

    face = "#{phone_card(1)} .booster-card__front .card"
    execute_script(<<~JS)
      const face = document.querySelector(#{face.to_json})
      const box = face.getBoundingClientRect()
      window.holdAt = [ box.left + box.width / 2, box.top + box.height / 2 ]
      face.dispatchEvent(new PointerEvent("pointerdown", { bubbles: true, pointerId: 7, pointerType: "touch", isPrimary: true, clientX: holdAt[0], clientY: holdAt[1] }))
    JS
    assert_selector "#{face}[data-tilting]", visible: :all
    execute_script(<<~JS)
      const face = document.querySelector(#{face.to_json})
      const event = (type, dx) => new PointerEvent(type, { bubbles: true, pointerId: 7, pointerType: "touch", isPrimary: true, clientX: holdAt[0] + dx, clientY: holdAt[1] })
      face.dispatchEvent(event("pointermove", 60))
      face.dispatchEvent(event("pointermove", 120))
      face.dispatchEvent(event("pointerup", 120))
    JS
    sleep 0.4

    assert_selector "#{phone_card(1)}[data-top][data-revealed]"
    assert_equal 0, filled_slots
    assert_equal "", find("#{phone_card(1)} .booster-card__float", visible: :all).evaluate_script("this.style.transform")
  end

  test "a width crossing 720px draws the same hand again: no request, nothing replayed, the revealed cards in the tray and back" do
    open_screen(card_ids(:common_card_one, :uncommon_card_one, :rare_card_one, :portal_one, :common_card_one))
    open_canister
    assert_dealt(5)
    find(hit(1)).click
    find(hit(2)).click
    assert_selector ".booster-card[data-revealed]", count: 2
    first, second = revealed_at(1), revealed_at(2)

    on_phone
    assert_selector ".booster[data-layout=phone]"
    assert_selector ".booster__pile .booster-card", count: 3
    assert_selector ".booster__pile .booster-card[data-revealed]", count: 0
    assert_selector ".booster-tray__slot--filled", count: 2
    assert_selector ".booster-tray__count", text: %r{CARD\s+2 / 5}
    assert_selector "#{phone_card(3)}[data-top]"
    assert_selector ".booster__state", text: /\AINVENTORY\z/

    page.driver.browser.manage.window.resize_to(*SCREEN_SIZE)
    assert_selector ".booster[data-layout=wide]"
    assert_selector ".booster__deal .booster-card[data-dealt]", count: 5
    assert_selector ".booster-card[data-revealed]", count: 2
    assert_equal [ first, second ], [ revealed_at(1), revealed_at(2) ]
    assert_selector ".booster__counter", text: "Cards revealed: 2 / 5"
    assert_equal 1, request_keys.size
    assert_equal 1, opened_packs
  end

  test "a width change during a reveal waits for it to end" do
    open_screen(card_ids(:legendary_card_one, *[ :common_card_one ] * 4))
    open_canister
    assert_dealt(5)
    # A Légendaire's still banner holds its reveal 1.4 s under reduced motion.
    find(hit(1)).click
    assert_selector ".booster__state", text: "LEGENDARY SIGNAL"
    on_phone
    assert_selector ".booster[data-layout=wide]"
    assert_selector ".booster[data-layout=phone]", wait: 5
    assert_selector ".booster-tray__slot--filled", count: 1
    assert_selector ".booster__pile .booster-card", count: 4
  end

  test "from 720 to 899px the cards are dealt small, and step up to medium past 900px" do
    page.driver.browser.manage.window.resize_to(800, 900)
    open_screen(card_ids(*[ :common_card_one ] * 5))
    assert_selector ".booster[data-layout=narrow]"
    open_canister
    assert_dealt(5)

    assert_selector ".booster-card__front .card.card--s", count: 5, visible: :all
    assert_equal [ 112 ] * 5, page.evaluate_script("[...document.querySelectorAll('.booster-card')].map((slot) => slot.getBoundingClientRect().width)")
    find(hit(1)).click
    assert_selector "#{card(1)}[data-revealed]"

    page.driver.browser.manage.window.resize_to(1000, 900)
    assert_selector ".booster[data-layout=wide]"
    assert_selector ".booster-card__front .card.card--m", count: 5, visible: :all
    assert_selector ".booster-card[data-revealed]", count: 1
    assert_equal 1, request_keys.size
  end

  test "before the answer, a daily bonus pack first in line is counted as three cards" do
    open_screen(card_ids(:rare_card_one, :portal_one, :legendary_card_one), kind: :bonus)

    assert_selector ".booster-canister[aria-label='Open the booster Season 1, grand catalogue, 3 cards']"
    assert_selector ".booster__row", text: /CARDS PER BOOSTER\s+3/
    assert_selector ".booster__counter", text: "Cards revealed: — / 3"

    on_phone
    assert_selector ".booster__canister-facts", text: "3 cards"
  end

  test "on a phone at most six loops run: at rest after the deal and after an Épique's reveal" do
    reduce_motion(false)
    on_phone
    open_screen(card_ids(:portal_one, *[ :common_card_one ] * 4))
    assert_operator infinite_loops, :<=, 6
    open_canister
    assert_pile(5)
    assert_selector ".booster__state", text: /\AINVENTORY\z/
    assert_operator infinite_loops, :<=, 6
    assert_operator infinite_loops, :>=, 1

    find(phone_hit(1)).click
    assert_selector "#{phone_card(1)}[data-revealed]"
    assert_no_selector "[aria-disabled=true].booster__back", wait: 5
    assert_operator infinite_loops, :<=, 6
  end

  test "on a phone the BOOSTER tab leads to the screen, which opens and reveals on the pile" do
    on_phone
    create_pack(@player, cards: card_ids(:common_card_one, :uncommon_card_one, :rare_card_one, :portal_one, :legendary_card_one))
    visit home_path(locale: :en)
    find(".tab-bar a.tab-bar__tab", text: /BOOSTER/).click

    assert_current_path "/en/booster"
    assert_selector ".tab-bar a.tab-bar__tab[aria-current=page]", text: /BOOSTER/
    record_requests
    open_canister
    assert_pile(5)
    find(phone_hit(1)).click
    assert_selector ".booster-plate", text: /COMMON/
    assert page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth"), "the page should not scroll sideways"
  end
end
