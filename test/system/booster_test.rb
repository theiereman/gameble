require "application_system_test_case"
require_relative "../support/game_packs"
require_relative "../support/steam_sign_in"

# The booster screen: the canister sends the opening exchange and deals the
# cards face down; one activation reveals a card, "Reveal all" the rest;
# the top bar's rarity counter rises at each reveal and its reserve chip
# follows each answer. A held capsule opens at once and is confirmed in the
# background, even across a cut network or a reload; with none held, a
# refusal leaves the canister at rest and says why, and a lost answer is
# retried with the same key. On a phone the cards land
# in a pile, each revealed card is stored in the tray (Store or a tap) and a
# filled slot opens the card zoom, which steps through the tray; a card's
# detail walks the booster and coming back shows it again, every card face
# up. Reduced motion is emulated in every test.
class BoosterTest < ApplicationSystemTestCase
  include GamePacks
  include SteamSignIn

  PHONE = [ 390, 844 ].freeze

  setup do
    @player = accounts_players(:player)
    mock_steam_sign_in(@player.steam_id)
    reduce_motion(true)
    visit home_path(locale: :en)
    click_steam_sign_in
    assert_signed_in
  end

  teardown do
    reduce_motion(false)
  end

  def reduce_motion(on)
    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", features: [ { name: "prefers-reduced-motion", value: on ? "reduce" : "" } ])
  end

  def card_ids(*names)
    names.map { |name| catalog_card_seasons(name).id }
  end

  # Packs holding these card-seasons, then the booster screen
  # drawn. `more` leaves another pack available after them.
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
        const key = init && init.headers && init.headers["Idempotency-Key"]
        if (key) window.boosterKeys.push(key)
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

  def legend_cell(tier, cell)
    "#rarity-legend .rarity-legend__row--#{tier} #{cell}"
  end

  def opened_packs
    Game::Pack.where(player_id: @player.id).where.not(opened_at: nil).count
  end

  test "an opening deals the cards face down; each reveal shows its card, says it, and raises the top bar's count then" do
    open_screen(card_ids(:common_card_one, :uncommon_card_one, :rare_card_one, :portal_one, :common_card_one), more: true)
    commons = Integer(rarity_count("common"))

    open_canister
    assert_dealt(5)

    assert_equal 1, request_keys.size
    assert_match(/\A\h{8}-\h{4}-4\h{3}-[89ab]\h{3}-\h{12}\z/, request_keys.first)
    assert_selector ".booster-card:not([data-revealed])", count: 5
    assert_selector ".booster-card__back", count: 5
    assert_selector "#{card(1)} .booster-card__label", text: "? ? ?"
    assert_equal "Card 1 of 5, face down. Reveal.", find(hit(1))["aria-label"]
    assert_focus hit(1)
    # The reserve follows the answer; the counts wait for the reveals.
    assert_selector ".top-bar .packs-chip--static .packs-chip__count", text: "1"
    assert_selector ".booster__pip[data-lit]", count: 1
    assert_equal commons, Integer(rarity_count("common"))
    assert_selector ".booster__hint", text: "Click a card to reveal it · 5 left"
    assert_button "Open the next one", disabled: true

    page.send_keys(:enter)
    assert_selector "#{card(1)}[data-revealed]"
    assert_selector "#{card(1)} .booster-card__label", text: "COMMON"
    assert_announced "Card 1: Tin Soldier — 2024. Common."
    assert_equal commons + 1, Integer(rarity_count("common"))
    assert_equal "Tin Soldier — 2024, Common. See the card.", find(hit(1))["aria-label"]
    assert_focus hit(1)

    find(hit(4)).click
    assert_selector "#{card(4)}[data-revealed] .booster-card__label", text: "EPIC"
    assert_announced "Card 4: Portal — Valve, 2007. Epic."
    assert_equal commons + 1, Integer(rarity_count("common"))
    assert_selector "#{card(4)} .booster-card__front .card.card--m.card--booster.card--rarity-epic"
  end

  def reposts = Game::FeedEntry.where(kind: "repost").pluck(:card_season_id)

  test "a revealed card is reposted from under it with a toast, the hand staying as it is" do
    open_screen(card_ids(:common_card_one, :uncommon_card_one, :rare_card_one, :portal_one, :common_card_one))
    open_canister
    assert_dealt(5)
    assert_no_selector ".booster-card__repost"

    find(hit(4)).click
    assert_selector "#{card(4)}[data-revealed]"
    assert_selector "#{card(4)} .booster-card__repost", count: 1
    assert_equal "Repost Portal", find("#{card(4)} .booster-card__repost")["aria-label"]
    assert_no_selector "#{card(1)} .booster-card__repost"

    find("#{card(4)} .booster-card__repost").click

    assert_selector "#toasts .toast--notice", text: /card reposted to the feed\./i
    assert_current_path "/en/booster"
    assert_selector "#{card(4)} .booster-card__repost"
    assert_selector ".booster-card[data-revealed]", count: 1
    assert_equal card_ids(:portal_one), reposts
  end

  def opened_token
    Game::Pack.where(player_id: @player.id).where.not(opened_at: nil).order(:opened_at).last.token
  end

  # Waits for the detail of `title`, then steps once with ◀ or ▶.
  def step_detail(side, to:)
    find(".card-detail__nav--#{side}").click
    assert_selector ".card-detail h1", text: to
    assert_no_selector "html[data-sub-view-step]", visible: :all
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
    assert_includes announcements, "Legendary signal"
    assert_selector ".booster__state", text: "INVENTORY COMPLETE"
    assert_selector ".booster__hint", text: "Capsule inventoried · +5 cards in the collection"
    assert_selector "#{card(2)} .booster-card__label", text: "LEGENDARY!"
    assert_focus ".booster__open"
    assert_button "Open the next one"
  end

  test "when a reveal ends the rarity legend counts the capsule, in copies and in owned cards, without a visit" do
    open_screen(card_ids(:common_card_one, :uncommon_card_one, :rare_card_one, :portal_one, :common_card_one), more: true)
    commons = Integer(rarity_count("common"))
    copies = legend_cell(1, ".rarity-legend__copies")
    assert_selector copies, text: commons.to_s, exact_text: true, visible: :all

    open_canister
    assert_dealt(5)
    assert_selector copies, text: commons.to_s, exact_text: true, visible: :all

    click_on "Reveal all"
    assert_selector ".booster-card[data-revealed]", count: 5, wait: 15

    assert_selector copies, text: (commons + 2).to_s, exact_text: true, visible: :all, wait: 10
    owned = Game::RarityLegend.call(@player).rows.first.overall.owned
    assert_selector legend_cell(1, ".rarity-legend__overall .rarity-legend__owned"), text: owned.to_s, exact_text: true, visible: :all
    assert_equal commons + 2, Integer(rarity_count("common"))
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
    eventually("both capsules should be opened") { opened_packs == 2 }

    click_on "Reveal all"
    assert_selector ".booster-card[data-revealed]", count: 5, wait: 10
    assert_button "Reserve empty", disabled: true
    assert_focus ".top-bar__home"
    assert_selector ".top-bar .packs-chip--static .packs-chip__count", text: "0"
  end

  test "an empty reserve whose next booster arrives while the screen shows: the canister appears without a page visit and opens at once" do
    create_pack(@player, available_at: 5.seconds.from_now)
    visit booster_path(locale: :en)
    assert_selector ".booster__empty"
    assert_button "Reserve empty", disabled: true
    page.execute_script("document.querySelector('.booster').dataset.kept = '1'")

    assert_selector ".booster-canister", wait: 15
    assert_button "Open the capsule", disabled: false
    assert_selector ".booster__state", text: "SEALED"
    assert_selector ".top-bar .packs-chip--static .packs-chip__count", text: "1"
    assert_selector ".booster[data-kept]"

    cut_network
    open_canister
    assert_dealt(5)
  end

  # The screen as drawn with no held capsule: the root controller reconnects
  # reading none, so an opening takes the waiting path.
  def without_held_capsules
    page.evaluate_async_script(<<~JS)
      const done = arguments[0]
      const root = document.querySelector(".booster")
      root.dataset.boosterHeldValue = "{}"
      root.removeAttribute("data-controller")
      setTimeout(() => {
        root.dataset.controller = "booster"
        setTimeout(done, 0)
      }, 0)
    JS
  end

  # Every opening request fails as if the network were cut, until `online`.
  def cut_network
    page.execute_script(<<~JS)
      window.networkCut = true
      const reachingFetch = window.fetch
      window.fetch = (url, init) => {
        if (window.networkCut && init && init.method === "POST") return Promise.reject(new TypeError("Failed to fetch"))
        return reachingFetch(url, init)
      }
    JS
  end

  def restore_network
    page.execute_script("window.networkCut = false; window.dispatchEvent(new Event('online'))")
  end

  test "with the network cut, a held capsule deals and reveals its cards; it is confirmed once the network returns, nothing more opened" do
    open_screen(card_ids(*[ :rare_card_one ] * 5))
    cut_network

    open_canister
    assert_dealt(5)
    assert_selector ".booster-card[data-tier=rare]", count: 5
    click_on "Reveal all"
    assert_selector ".booster-card[data-revealed]", count: 5, wait: 10
    assert_selector "#{card(1)} .booster-card__front .card--rarity-rare"
    assert_no_selector ".toasts .toast"
    assert_no_selector ".booster__reason"
    assert_equal 0, opened_packs

    restore_network
    eventually("the held capsule should be opened once") { opened_packs == 1 }
    assert_equal 1, request_keys.uniq.size
    assert_opened_once(@player)
  end

  test "a capsule queued offline is not offered again after a reload: the queue confirms it, then the next capsule opens" do
    open_screen(card_ids(*[ :rare_card_one ] * 5), card_ids(*[ :uncommon_card_one ] * 5))
    cut_network
    open_canister
    assert_dealt(5)
    assert_selector ".top-bar .packs-chip--static .packs-chip__count", text: "1"

    visit booster_path(locale: :en)
    eventually("the queued capsule should be confirmed after the reload") { opened_packs == 1 }
    assert_selector ".top-bar .packs-chip--static .packs-chip__count", text: "1"

    open_canister
    assert_dealt(5)
    assert_selector ".booster-card[data-tier=uncommon]", count: 5
    eventually("the next capsule should be opened") { opened_packs == 2 }
    assert_opened_once(@player)
  end

  test "a held capsule no longer in the reserve: its hand stays, the refusal is said aloud without a toast, and the reserve refreshes" do
    open_screen(card_ids(*[ :common_card_one ] * 5))
    Game::Pack.where(player_id: @player.id).update_all(available_at: 1.day.from_now)
    message = I18n.t("errors.game.pack_not_available", locale: :en)

    open_canister

    assert_dealt(5)
    assert_announced message
    assert_no_selector ".toasts .toast"
    assert_selector ".top-bar .packs-chip--static .packs-chip__count", text: "0"
    assert_equal 1, request_keys.size
    assert_equal 0, opened_packs
  end

  test "a capsule already opened elsewhere deals that same capsule, nothing opened twice" do
    open_screen(card_ids(*[ :rare_card_one ] * 5), more: true)
    Game::OpenPack.new.call(player: @player).value!

    open_canister

    assert_dealt(5)
    assert_selector ".booster-card[data-tier=rare]", count: 5
    assert_no_selector ".toasts .toast"
    eventually("the confirmation should land") { request_keys.size == 1 }
    assert_equal 1, opened_packs
  end

  test "with no held capsule, a refusal (the reserve emptied elsewhere) deals nothing and says why, inline, in a toast and aloud" do
    open_screen(card_ids(*[ :common_card_one ] * 5))
    without_held_capsules
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

  test "with no held capsule, a lost answer says the capsule is safe; the next activation sends the same key and gets the same pack" do
    open_screen(card_ids(*[ :rare_card_one ] * 5), card_ids(*[ :common_card_one ] * 5))
    without_held_capsules
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
    failed = I18n.t("booster.strings.failed", locale: :en)
    assert_selector ".booster__reason", text: failed
    assert_selector ".toasts .toast--alert", text: failed
    assert_no_selector ".toasts .toast--alert", text: /OPENING CANCELLED/
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

  # ---- The phone, the narrow row and the rebuild ----

  def phone_card(position)
    ".booster-card[data-position='#{position}']"
  end

  def phone_hit(position)
    "#{phone_card(position)} .booster-card__hit"
  end

  def canister_top
    evaluate_script("Math.round(document.querySelector('.booster-canister').getBoundingClientRect().top - document.querySelector('.booster__stage').getBoundingClientRect().top)")
  end

  def on_phone
    page.driver.browser.manage.window.resize_to(*PHONE)
  end

  # The phone's pile dealt: every card at card-xl, the first on top with the focus.
  def assert_pile(count)
    assert_selector ".booster[data-layout=phone] .booster__pile .booster-card[data-dealt]", count:, wait: 10
    assert_selector ".booster__state", text: /\AINVENTORY\z/
  end

  def filled_slots
    all(".booster-tray__slot--filled").size
  end

  test "on a phone: a pile of large cards, one at a time, each revealed then stored by Store or a tap, the focus following" do
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
    assert_button "Open the capsule"
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
    sleep 0.45
    click_on "Store"
    assert_no_selector phone_card(1)
    assert_selector ".booster-tray__slot--filled[data-tier=common]", count: 1
    assert_selector ".booster-tray__count", text: %r{CARD\s+1 / 5}
    assert_focus phone_hit(2)

    # The second: a tap on the revealed card, once its guard is over.
    page.send_keys(:enter)
    assert_selector "#{phone_card(2)}[data-revealed]"
    sleep 0.45
    find("#{phone_card(2)} .booster-card__front .card").click
    assert_no_selector phone_card(2)
    assert_equal 2, filled_slots
    assert_focus phone_hit(3)

    page.send_keys(:enter)
    assert_selector "#{phone_card(3)}[data-revealed]"
    sleep 0.45
    click_on "Store"
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
    assert_selector ".booster-plate-band .booster-celebration", text: /SET COMPLETE\s+VALVE/
    assert_focus ".booster__open"
    assert_button "Open the next one"

    # The set result holds the stage alone; Continue lets the next capsule dock there.
    assert_no_selector ".booster-canister"
    click_on "Continue"
    assert_no_selector ".booster-celebration"
    assert_selector ".booster-canister"
    assert_focus ".booster__open"
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
    assert_current_path "/en/cards/blue-depths?pack=#{opened_token}&slot=1"
  end

  test "on a phone the card zoom reposts its card with a toast" do
    on_phone
    open_screen(card_ids(*[ :rare_card_one ] * 5))
    open_canister
    assert_pile(5)
    assert_no_selector ".booster-card__repost"
    page.send_keys(:enter)
    assert_selector "#{phone_card(1)}[data-revealed]"
    assert_no_selector ".booster-card__repost"
    sleep 0.45
    click_on "Store"

    find(".booster-tray__slot--filled").click
    assert_selector "dialog.booster-zoom[open]"
    watch_toasts_over_modal
    within("dialog.booster-zoom[open]") { click_on "Repost" }

    assert_selector "#toasts .toast--notice", text: /card reposted to the feed\./i
    assert_selector "dialog.booster-zoom[open] .booster-zoom__status[role=status]", text: "Card reposted to the feed.", visible: :all
    page.document.synchronize { raise Capybara::ExpectationNotMet, "the toast is drawn under the card zoom" unless evaluate_script("window.toastsShownOverModal") }
    assert_equal card_ids(:rare_card_one), reposts
  end

  # The top layer draws last what was shown last; a modal dialog leaves the
  # rest of the page inert, so hit testing cannot tell what is drawn on top.
  def watch_toasts_over_modal
    execute_script(<<~JS)
      window.toastsShownOverModal = false
      document.getElementById("toasts").addEventListener("toggle", (event) => {
        if (event.newState === "open" && document.querySelector("dialog:modal")) window.toastsShownOverModal = true
      })
    JS
  end

  test "on a phone the zoom steps through the tray with ◀ ▶; its detail walks the booster, and ◀ Booster brings it back stored" do
    on_phone
    open_screen(card_ids(:common_card_one, :uncommon_card_one, :rare_card_one, :portal_one, :legendary_card_one))
    open_canister
    assert_pile(5)
    click_on "Reveal all"
    assert_selector ".booster-tray__slot--filled", count: 5, wait: 20
    assert_selector ".booster__state", text: "INVENTORY COMPLETE", wait: 10
    token = opened_token

    all(".booster-tray__slot--filled")[2].click
    zoom = "dialog.booster-zoom[open]"
    assert_selector "#{zoom} h2", text: "BLUE DEPTHS"
    assert_equal [ "Previous card", "Next card" ], all("#{zoom} .booster-zoom__nav").map { it["aria-label"] }
    find("#{zoom} .booster-zoom__nav--next").click
    assert_selector "#{zoom} h2", text: "PORTAL"
    find("#{zoom} .booster-zoom__nav--next").click
    assert_selector "#{zoom} h2", text: "GOLDEN CROWN"
    assert_selector "#{zoom} .booster-zoom__nav--next[disabled]"
    [ "PORTAL", "BLUE DEPTHS", "GREEN HILLS", "TIN SOLDIER" ].each do |title|
      find("#{zoom} .booster-zoom__nav--previous").click
      assert_selector "#{zoom} h2", text: title
    end
    assert_selector "#{zoom} .booster-zoom__nav--previous[disabled]"
    assert_selector "#{zoom} .booster-zoom__card .card.card--xl.card--rarity-common", visible: :all
    page.send_keys(:escape)
    assert_no_selector "dialog.booster-zoom"
    assert_focus ".booster-tray__item:nth-child(1) .booster-tray__slot"

    all(".booster-tray__slot--filled")[1].click
    click_on "See the card"
    assert_current_path "/en/cards/green-hills?pack=#{token}&slot=2"
    assert_selector ".card-detail__position", text: "· 2 / 5 · SWIPE TO BROWSE"
    step_detail(:next, to: "Blue Depths")
    assert_selector ".card-detail__position", text: "· 3 / 5 ·"
    back = find(".top-bar__phone-back", text: "CAPSULE")
    assert_equal "/en/booster?pack=#{token}", URI(back[:href]).request_uri

    back.click
    assert_current_path "/en/booster?pack=#{token}"
    assert_selector ".booster[data-layout=phone]"
    assert_selector ".booster-tray__slot--filled", count: 5
    assert_no_selector ".booster__pile .booster-card"
    assert_selector ".booster__state", text: "INVENTORY COMPLETE"
    all(".booster-tray__slot--filled")[4].click
    assert_selector "dialog.booster-zoom[open] h2", text: "GOLDEN CROWN"
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

  test "on a phone the next capsule waits on the stage once the hand is stored, and a tap on it opens it" do
    on_phone
    open_screen(card_ids(*[ :common_card_one ] * 5), card_ids(*[ :uncommon_card_one ] * 5))
    sealed_at = canister_top
    open_canister
    assert_pile(5)
    assert_no_selector ".booster-canister"

    click_on "Reveal all"
    assert_selector ".booster-tray__slot--filled", count: 5, wait: 20
    assert_selector ".booster-canister"
    # It waits exactly where a sealed capsule sits, so opening it does not make it jump.
    page.document.synchronize { raise Capybara::ExpectationNotMet, "the capsule sits at #{canister_top}, not #{sealed_at}" unless canister_top == sealed_at }

    find(".booster-canister").click
    assert_selector ".booster-card[data-tier=uncommon]", count: 5, wait: 10
    assert_selector ".booster-tray__slot--filled", count: 0
    assert_equal 2, request_keys.uniq.size
  end

  test "on the wide layout the set celebration waits for the last reveal, is announced once, and comes back still from its album" do
    open_screen(card_ids(:common_card_one, :uncommon_card_one, :rare_card_one, :portal_one, :common_card_one), more: true)
    open_canister
    assert_dealt(5)

    (1..4).each do |position|
      find(hit(position)).click
      assert_selector "#{card(position)}[data-revealed]"
      assert_no_selector "[data-navigation-locked]", visible: :all
      assert_no_selector ".booster-celebration"
    end
    find(hit(5)).click
    assert_selector ".booster__state", text: "INVENTORY COMPLETE"
    assert_selector ".booster__info .booster-celebration", text: /SET COMPLETE\s+VALVE/
    assert_no_selector ".booster__info .booster-celebration[data-still]"
    assert_selector ".booster [role=status] > span", text: /\ASet complete: /, count: 1, visible: :all

    find(".booster__info .booster-celebration a.booster-celebration__banner").click
    assert_current_path library_set_path(locale: :en, kind: "studio", key: "valve")

    page.go_back
    assert_selector ".booster-card[data-revealed]", count: 5
    assert_selector ".booster__info .booster-celebration[data-still]", text: /SET COMPLETE\s+VALVE/
    assert_selector ".booster__state", text: "INVENTORY COMPLETE"

    click_on "Open the next one"
    assert_no_selector ".booster-celebration"
    assert_dealt(5)
    assert_no_selector ".booster [role=status] > span", text: /\ASet complete: /, visible: :all
  end
end
