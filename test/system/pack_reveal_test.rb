require "application_system_test_case"
require_relative "../support/game_packs"

# The pack reveal (CAP-5, story 3.6): right after an opening the cards lie
# face down; wiping shows the seal, flipping the game; flip all holds a gold
# card its full length; on a phone one card at a time. Any later visit shows
# the faces. Reduced motion is emulated in every test but one, which times the
# gold flourish with motion on.
class PackRevealTest < ApplicationSystemTestCase
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

  # Opens a pack holding these card-seasons from the attic chest, and waits
  # for the island. `more` leaves another pack available after it.
  def open_pack(cards, kind: :regular, more: false)
    create_pack(@player, cards:, kind:, available_at: 1.day.ago)
    create_pack(@player, available_at: 1.hour.ago) if more
    visit home_path(locale: :en)
    find(".attic__object--chest button").click
    assert_selector ".pack-reveal"
    Game::Pack.where(player_id: @player.id).where.not(opened_at: nil).order(:opened_at).last
  end

  def card(position)
    ".pack-reveal__item:nth-child(#{position}) .reveal-card"
  end

  def state(position)
    find(card(position))["data-state"]
  end

  def flipped_at(position)
    Float(find(card(position))["data-flipped-at"])
  end

  # The whole reveal of the card, read from the length the island gives it.
  def reveal_ms(position)
    page.evaluate_script("parseFloat(document.querySelector(#{card(position).to_json}).style.getPropertyValue('--reveal-ms'))")
  end

  def seal_visibility(position)
    page.evaluate_script("getComputedStyle(document.querySelector(#{"#{card(position)} .card__seal".to_json})).visibility")
  end

  # The latest announcement; earlier ones stay in the live region.
  def announced
    announcements.last
  end

  def assert_announced(text, wait: Capybara.default_max_wait_time)
    assert_selector ".pack-reveal [role=status] > span:last-child", text:, exact_text: true, visible: :all, wait:
  end

  def announcements
    all(".pack-reveal [role=status] > span", visible: :all).map { it.text(:all) }
  end

  def wait_until_all_flipped(count)
    assert_selector ".reveal-card[data-state=flipped]", count:, wait: 20
    assert_announced "Every card is turned, Brother.", wait: 20
  end

  test "keyboard only: focus wipes and shows the seal, Enter flips, every card in turn" do
    pack = open_pack(card_ids(:steel_card_one, :emerald_card_one, :gold_card_one, :sapphire_card_one, :portal_one))

    assert_selector ".reveal-card[data-state=dusty]", count: 5
    assert_not_includes page.html, pack.token
    (1..5).each { |position| assert_equal "hidden", seal_visibility(position) }
    assert_equal "Face-down card", find(card(1))["aria-label"]

    page.execute_script("document.querySelector('.pack-reveal__controls .button').focus()")
    titles = [ "Tin Soldier", "Green Hills", "Golden Crown", "Blue Depths", "Portal" ]
    rarities = %w[Steel Emerald Gold Sapphire Amethyst]
    titles.zip(rarities).each.with_index(1) do |(title, rarity), position|
      page.send_keys(:tab)
      assert_selector "#{card(position)}[data-state=wiped]"
      assert_equal "visible", seal_visibility(position)
      assert_equal "Face-down card, #{rarity}", find(card(position))["aria-label"]
      assert_equal rarity, announced

      page.send_keys(:enter)
      assert_selector "#{card(position)}[data-state=flipped][aria-disabled=true]"
      assert_nil find(card(position))["aria-label"]
      assert_selector "#{card(position)} .reveal-card__face .card__title", text: title
      assert_equal title, announced
    end
  end

  test "a mouse over a card wipes it, a click on a dusty card flips it; a card without dust keeps its seal hidden until wiped" do
    open_pack(card_ids(:steel_card_one, :emerald_card_one, :sapphire_card_one, :portal_one, :gold_card_one))

    assert_selector "#{card(1)} .card--dust-0"
    assert_equal "hidden", seal_visibility(1)
    find(card(1)).hover
    assert_equal "wiped", state(1)
    assert_equal "visible", seal_visibility(1)

    page.execute_script("document.querySelector(#{card(2).to_json}).click()")
    assert_equal "flipped", state(2)
    assert_equal "Green Hills", announced
    assert_equal "dusty", state(3)

    # A wipe then a flip in one gesture: the rarity is not replaced by the title.
    find(card(3)).click
    assert_equal "flipped", state(3)
    assert_equal [ "Sapphire", "Blue Depths" ], announcements.last(2)
  end

  test "flip all holds the one gold card its full length and flips the others quickly" do
    open_pack(card_ids(:steel_card_one, :gold_card_one, :emerald_card_one, :sapphire_card_one, :steel_card_one))

    click_on "Flip all"
    wait_until_all_flipped(5)

    assert_equal 2800, reveal_ms(2)
    [ 1, 3, 4, 5 ].each { |position| assert_equal 600, reveal_ms(position) }
    assert_operator flipped_at(3) - flipped_at(2), :>=, reveal_ms(2)
    assert_operator flipped_at(2) - flipped_at(1), :<, 1000
  end

  test "five identical gold cards flip one by one; flip all skips those flipped and holds each other gold" do
    open_pack(card_ids(*[ :gold_card_one ] * 5))

    page.execute_script("document.querySelector(#{card(2).to_json}).click()")
    assert_equal "flipped", state(2)
    assert_equal %w[dusty flipped dusty dusty dusty], (1..5).map { state(it) }
    page.execute_script("document.querySelector(#{card(4).to_json}).click()")
    before = [ flipped_at(2), flipped_at(4) ]

    click_on "Flip all"
    wait_until_all_flipped(5)

    assert_equal before, [ flipped_at(2), flipped_at(4) ]
    assert_operator flipped_at(3) - flipped_at(1), :>=, reveal_ms(1)
    assert_operator flipped_at(5) - flipped_at(3), :>=, reveal_ms(3)
  end

  test "with reduced motion nothing moves, and no dust bursts" do
    open_pack(card_ids(:gold_card_one, :steel_card_one, :steel_card_one, :steel_card_one, :steel_card_one))

    find(card(1)).click
    assert_selector "#{card(1)}[data-state=flipped][data-playing]"
    face = "#{card(1)} .reveal-card__face"
    assert_equal "none", page.evaluate_script("getComputedStyle(document.querySelector(#{face.to_json})).animationName")
    assert_equal "visible", page.evaluate_script("getComputedStyle(document.querySelector(#{face.to_json})).visibility")
    assert_no_selector ".reveal-card__burst", visible: :all
  end

  test "with motion, a gold card turns, bursts and shines for its full length; flip all holds the next gold" do
    reduce_motion(false)
    open_pack(card_ids(:gold_card_one, :steel_card_one, :gold_card_one, :steel_card_one, :steel_card_one))

    find(card(1)).click
    assert_selector "#{card(1)} .reveal-card__pixel", count: 32, visible: :all
    assert_selector "#{card(1)} .reveal-card__ray", count: 8, visible: :all
    animations = page.evaluate_script("getComputedStyle(document.querySelector(#{"#{card(1)} .reveal-card__face".to_json})).animationName")
    assert_equal "reveal-turn-in, reveal-hold", animations
    assert_no_selector "#{card(1)} .reveal-card__burst", visible: :all, wait: 5
    assert_operator page.evaluate_script("performance.now()") - flipped_at(1), :>=, reveal_ms(1)

    click_on "Flip all"
    wait_until_all_flipped(5)
    assert_operator flipped_at(4) - flipped_at(3), :>=, reveal_ms(3)
  end

  test "a card whose art fails shows its frame and title" do
    open_pack(card_ids(*[ :sapphire_card_one ] * 5))

    find(card(1)).click
    within(card(1)) do
      assert_selector ".card__art[data-art=failed]"
      assert_selector ".card__frame", visible: :all
      assert_selector ".card__title", text: "Blue Depths"
    end
  end

  test "leaving during flip all raises no error; going back shows the faces, without the reveal" do
    open_pack(card_ids(*[ :gold_card_one ] * 5))
    page.execute_script(<<~JS)
      window.revealErrors = []
      addEventListener("error", (event) => revealErrors.push(String(event.message)))
      addEventListener("unhandledrejection", (event) => revealErrors.push(String(event.reason)))
    JS

    click_on "Flip all"
    assert_selector ".reveal-card[data-state=flipped]"
    within(".pack-reveal .pack-end") { click_on "Back to the attic" }
    assert_selector ".attic"
    sleep 3
    assert_equal [], page.evaluate_script("window.revealErrors")

    page.go_back
    assert_selector ".pack-result__card .card--face", count: 5
    assert_no_selector ".pack-reveal"
  end

  test "a reload mid-reveal shows the faces, and nothing resumes" do
    open_pack(card_ids(:steel_card_one, :emerald_card_one, :sapphire_card_one, :portal_one, :gold_card_one))
    find(card(1)).click

    page.refresh

    assert_selector ".pack-result__card .card--face", count: 5
    assert_no_selector ".pack-reveal"
  end

  # Waits for the focus to match: a view change made by flip all's timers
  # moves the focus in an effect, just after the new card is drawn.
  def assert_focus(selector, message)
    page.document.synchronize do
      raise Capybara::ExpectationNotMet, message unless page.evaluate_script("document.activeElement.matches(#{selector.to_json})")
    end
  end

  test "on a phone one large card at a time, focus following next; flip all holds each gold, then every card is reached forward and back" do
    page.driver.browser.manage.window.resize_to(*PHONE)
    open_pack(card_ids(:steel_card_one, :gold_card_one, :emerald_card_one, :gold_card_one, :steel_card_one))

    assert_selector ".pack-reveal--phone .reveal-card.reveal-card--large", count: 1
    assert_selector ".pack-reveal__progress", text: "1 / 5"
    assert_no_button "Next card"
    assert_no_button "Previous card"

    find(".reveal-card").click
    assert_selector ".reveal-card[data-state=flipped]"
    click_on "Next card"
    assert_selector ".pack-reveal__progress", text: "2 / 5"
    assert_selector ".reveal-card[data-state=wiped]"
    assert page.evaluate_script("document.activeElement.classList.contains('reveal-card')"), "focus should move to the new card"
    assert page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth"), "the page should not scroll sideways"

    # Flip all with the focus left on the shown card (as a tap does on Safari,
    # which does not focus buttons): each gold card is the one shown while it
    # is held, flipped, its full length; the focus follows the view.
    page.execute_script("document.querySelector('.pack-reveal__controls .button').click()")
    [ "2 / 5", "4 / 5" ].each do |progress|
      assert_selector ".pack-reveal__progress", text: progress, wait: 5
      assert_selector ".reveal-card", count: 1
      assert_selector ".reveal-card[data-state=flipped] .reveal-card__face .card--rarity-gold"
      assert_no_button "Previous card"
      assert_no_button "Next card"
      assert_focus ".reveal-card", "focus should stay on the shown card"
    end

    # The run over, the view is back on the first card it turned.
    assert_announced "Every card is turned, Brother.", wait: 10
    assert_selector ".pack-reveal__progress", text: "2 / 5"
    assert_focus ".pack-reveal *", "focus should stay in the reveal"

    # Every card, forward and back, face up, the focus kept in the reveal; each
    # gold card was held its full length before the next card turned.
    timings = {}
    click_on "Previous card"
    assert_selector ".pack-reveal__progress", text: "1 / 5"
    assert_no_button "Previous card"
    [ [ "Next card", 2..5 ], [ "Previous card", 4.downto(1) ] ].each do |control, positions|
      positions.each do |position|
        click_on control
        assert_selector ".pack-reveal__progress", text: "#{position} / 5"
        assert_selector ".reveal-card", count: 1
        assert_selector ".reveal-card[data-state=flipped]"
        assert_focus ".pack-reveal *", "focus should stay in the reveal"
        timings[position] ||= [ flipped_at(1), reveal_ms(1) ]
      end
    end
    assert_no_button "Previous card"
    [ 2, 4 ].each do |gold|
      assert_operator timings[gold + 1][0] - timings[gold][0], :>=, timings[gold][1], "gold card #{gold} should be held its full length"
    end
    take_screenshot
  end

  test "a daily bonus reveals three cards" do
    page.driver.browser.manage.window.resize_to(*PHONE)
    open_pack(card_ids(:sapphire_card_one, :portal_one, :gold_card_one), kind: :bonus)

    assert_selector "h1", text: "Your daily bonus"
    assert_selector ".pack-reveal__progress", text: "1 / 3"
  end

  test "crossing the phone width switches the layout and draws the art again" do
    open_pack(card_ids(:steel_card_one, :emerald_card_one, :sapphire_card_one, :portal_one, :gold_card_one))
    assert_selector ".reveal-card--small", count: 5
    assert_selector ".card__art[data-art]", count: 5, visible: :all

    page.driver.browser.manage.window.resize_to(*PHONE)
    assert_selector ".pack-reveal--phone .reveal-card--large", count: 1
    assert_equal 104, page.evaluate_script("document.querySelector('.reveal-card .card__canvas').width")
    assert_selector ".reveal-card .card__art[data-art]", visible: :all

    page.driver.browser.manage.window.resize_to(*SCREEN_SIZE)
    assert_selector ".reveal-card--small", count: 5
    assert_equal 68, page.evaluate_script("document.querySelector('.reveal-card .card__canvas').width")

    # Into the phone layout: the first card not flipped, or the focused one, keeping focus.
    page.execute_script("document.querySelector(#{card(1).to_json}).click()")
    page.driver.browser.manage.window.resize_to(*PHONE)
    assert_selector ".pack-reveal__progress", text: "2 / 5"
    page.driver.browser.manage.window.resize_to(*SCREEN_SIZE)
    assert_selector ".reveal-card--small", count: 5
    page.execute_script("document.querySelector(#{card(4).to_json}).focus()")
    page.driver.browser.manage.window.resize_to(*PHONE)
    assert_selector ".pack-reveal__progress", text: "4 / 5"
    assert page.evaluate_script("document.activeElement.matches('.reveal-card[data-state=wiped]')"), "focus should stay on the card"
  end

  test "the reveal ends on the next pack when one is available, and on the attic alone when none is" do
    open_pack(card_ids(*[ :steel_card_one ] * 5), more: true)
    within(".pack-reveal .pack-end") do
      # Button labels are uppercased by CSS (DESIGN.md, Buttons).
      assert_equal [ "OPEN THE NEXT PACK", "BACK TO THE ATTIC" ], all(".button").map(&:text)
      click_on "Open the next pack"
    end

    # Turbo disables the button while the form is sent: wait for the form to go.
    assert_no_selector ".pack-reveal .pack-end form"
    assert_selector ".reveal-card[data-state=dusty]", count: 5
    within(".pack-reveal .pack-end") { assert_equal [ "BACK TO THE ATTIC" ], all(".button").map(&:text) }
  end
end
