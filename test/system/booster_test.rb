require "application_system_test_case"
require_relative "../support/game_packs"

# The booster screen (story 11; EXPERIENCE.md: Booster, Opening protocol):
# the canister sends the opening exchange and deals the cards face down;
# one activation reveals a card, "Reveal all" the rest; the top bar's
# rarity counter rises at each reveal and its reserve chip follows each
# answer; every refusal leaves the canister at rest and says why. Reduced
# motion is emulated in every test but the Légendaire's, which runs the
# whole choreography with motion on.
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
    assert_dealt(5)
    assert_no_selector "#{back}[aria-disabled]"

    # A Légendaire's still banner holds the lock 1.4 s under reduced motion.
    find(hit(1)).click
    assert_selector "#{back}[aria-disabled=true]"
    assert_no_selector "#{back}[aria-disabled]", wait: 5
    assert_selector ".booster__back:not([aria-disabled])"
  end

  test "on a phone the BOOSTER tab leads to the screen, which opens and reveals in a wrapping row" do
    page.driver.browser.manage.window.resize_to(*PHONE)
    create_pack(@player, cards: card_ids(:common_card_one, :uncommon_card_one, :rare_card_one, :portal_one, :legendary_card_one))
    visit home_path(locale: :en)
    find(".tab-bar a.tab-bar__tab", text: /BOOSTER/).click

    assert_current_path "/en/booster"
    assert_selector ".tab-bar a.tab-bar__tab[aria-current=page]", text: /BOOSTER/
    record_requests
    open_canister
    assert_dealt(5)
    find(hit(2)).click
    assert_selector "#{card(2)}[data-revealed] .booster-card__label", text: "UNCOMMON"
    assert page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth"), "the page should not scroll sideways"
  end
end
