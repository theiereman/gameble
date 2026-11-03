require "application_system_test_case"
require_relative "../support/catalog_seeds"
require_relative "../support/game_sets"
require_relative "../support/steam_sign_in"

# The Me page: the player's own profile, its title, card back and showcase
# each changed in a bottom sheet opened by touching them, the result shown
# on the profile at once.
class MePageTest < ApplicationSystemTestCase
  include CatalogSeeds
  include GameSets
  include SteamSignIn

  PHONE = [ 390, 844 ].freeze
  OPENERS = {
    "a.me-title-opener" => [ "me-title-sheet", "Profile title" ],
    "a.me-back-opener" => [ "me-back-sheet", "Card back" ],
    "a.me-showcase-opener" => [ "me-showcase-sheet", "Showcase" ]
  }.freeze

  setup do
    @player = accounts_players(:player)
    mock_steam_sign_in(@player.steam_id)
  end

  def sign_in_to_me
    visit home_path(locale: :en)
    click_steam_sign_in
    assert_signed_in
    visit me_path(locale: :en)
    assert_selector ".me[data-controller=me]"
  end

  def modal?(id) = evaluate_script("document.getElementById('#{id}').matches(':modal')")

  def assert_modal(id)
    assert_selector "dialog##{id}", visible: true
    eventually("##{id} should be a modal dialog") { modal?(id) }
    eventually("##{id} should be done rising") { evaluate_script("document.getElementById('#{id}').getAnimations({ subtree: true }).length === 0") }
  end

  def assert_focused(selector)
    page.document.synchronize(Capybara.default_max_wait_time) do
      focused = evaluate_script("document.activeElement?.outerHTML.slice(0, 120)")
      raise Capybara::ExpectationNotMet, "focus on #{focused}, not #{selector}" unless evaluate_script("document.activeElement?.matches(#{selector.to_json})")
    end
  end

  def open_sheet(opener, id)
    find(opener).click
    assert_modal(id)
  end

  def choose_two_cards
    [ catalog_card_seasons(:common_card_one), catalog_card_seasons(:rare_card_one) ].each do |card|
      Game::Holding.create!(player_id: @player.id, card_season_id: card.id, quantity: 1)
      Game::AddToShowcase.new.call(player: @player, card_season_id: card.id).value!
    end
  end

  def earn_titles
    season, cards = published_cards(5)
    set_id = insert_set(cards, { novice: 1, adept: 3, complete: 5 }, kind: "studio", key: "valve", params: { "studio" => "Valve" }, season:)
    Game::SetTier.insert_all!(%w[novice adept].map { |tier| { player_id: @player.id, set_id:, tier:, reached_by: "trade", reached_at: Time.current } })
  end

  def drag_first_slot_onto_last
    execute_script(<<~JS)
      const slots = document.querySelectorAll(".profile-showcase__slot")
      const centre = (slot) => { const box = slot.getBoundingClientRect(); return [box.left + box.width / 2, box.top + box.height / 2] }
      const [fromX, fromY] = centre(slots[0])
      const [toX, toY] = centre(slots[1])
      const pointer = (type, x, y) => new PointerEvent(type, { bubbles: true, cancelable: true, pointerId: 1, pointerType: "mouse", isPrimary: true, button: 0, clientX: x, clientY: y })
      slots[0].dispatchEvent(pointer("pointerdown", fromX, fromY))
      window.dispatchEvent(pointer("pointermove", (fromX + toX) / 2, (fromY + toY) / 2))
      window.dispatchEvent(pointer("pointermove", toX, toY))
      window.dispatchEvent(pointer("pointerup", toX, toY))
    JS
  end

  test "on a phone the title, the back preview and the showcase Edit each open their sheet as a modal named by its title, Escape giving the focus back" do
    resize_to(*PHONE)
    sign_in_to_me

    OPENERS.each do |opener, (id, title)|
      open_sheet(opener, id)
      assert_selector "dialog##{id}[aria-labelledby='#{id}-title'] ##{id}-title", text: /\A#{title}\z/i

      page.send_keys(:escape)

      assert_no_selector "dialog##{id}", visible: true
      assert_focused opener
    end
  end

  test "a card is moved from the keyboard on Me, the focus staying on the moved card's button" do
    choose_two_cards
    sign_in_to_me
    labels = all(".profile-showcase__slot .card-link").map { it[:"aria-label"] }

    find(".profile-showcase__slot:first-child form[data-direction='later'] button").send_keys(:enter)

    assert_selector ".profile-showcase__slot:first-child .card-link[aria-label=\"#{labels.last}\"]"
    assert_selector ".profile-showcase__slot:last-child form[data-direction='earlier'] button:focus"
  end

  test "a card dragged on Me is announced once the new order is saved, and kept after a reload" do
    choose_two_cards
    sign_in_to_me
    first_title = all(".profile-showcase__slot").first[:"data-title"]

    drag_first_slot_onto_last

    assert_selector "p[role=status]", text: "#{first_title} is now in place 2 of 2.", visible: :all
    assert_selector ".profile-showcase__slot:last-child[data-title=\"#{first_title}\"]"
    visit me_path(locale: :en)
    assert_selector ".profile-showcase__slot:last-child[data-title=\"#{first_title}\"]"
  end

  test "a title chosen in its sheet shows in the band with its toast, and no title removes it" do
    earn_titles
    sign_in_to_me
    assert_selector ".me-title-opener .me-opener__value", text: "Choose a title"

    open_sheet("a.me-title-opener", "me-title-sheet")
    within("#me-title-sheet") { click_on "Adept · Valve" }

    assert_selector ".toast", text: "TITLE EQUIPPED"
    assert_selector ".profile-band .me-title-opener .profile-title", text: "Adept · Valve"
    assert_no_selector "dialog#me-title-sheet", visible: true

    open_sheet("a.me-title-opener", "me-title-sheet")
    assert_selector "#me-title-sheet button[aria-current=true]", text: /\AAdept · Valve\z/i
    within("#me-title-sheet") { click_on "No title" }

    assert_selector ".toast", text: "TITLE REMOVED"
    assert_selector ".me-title-opener .me-opener__value", text: "Choose a title"
  end

  test "a back equipped in its sheet shows in the band's preview at once, the page kept" do
    Game::CardBackUnlock.record(@player.id, "set-theme-rpg", Time.current)
    sign_in_to_me
    assert_selector ".me-back-opener [data-me-target=preview] .me-back-opener__name", text: "Standard"
    execute_script("window.stayedOnPage = true")

    open_sheet("a.me-back-opener", "me-back-sheet")
    find("[data-key='set-theme-rpg'] .back-picker__back").click

    assert_selector ".back-picker__tile--active[data-key='set-theme-rpg']"
    assert_selector "p[role=status]", text: "Card back equipped. RPG will show on your face-down cards.", visible: :all
    assert_selector ".me-back-opener [data-me-target=preview] .me-back-opener__name", text: "RPG", visible: :all
    assert_selector ".me[data-worn-back='set-theme-rpg']"
    assert evaluate_script("window.stayedOnPage")
    assert_equal "set-theme-rpg", Game::PlayerState.where(player_id: @player.id).pick(:active_card_back)

    page.send_keys(:escape)
    assert_selector ".me-back-opener .me-back-opener__name", text: "RPG"
    visit me_path(locale: :en)
    assert_selector ".me-back-opener .me-back-opener__name", text: "RPG"
  end

  test "a back equipped on Me stays in the preview once the page is restored from the cache by Back, and equipping goes on from there" do
    Game::CardBackUnlock.record(@player.id, "set-theme-rpg", Time.current)
    sign_in_to_me
    open_sheet("a.me-back-opener", "me-back-sheet")
    find("[data-key='set-theme-rpg'] .back-picker__back").click
    assert_selector ".me-back-opener .me-back-opener__name", text: "RPG", visible: :all
    execute_script("document.querySelector('.me').dataset.restored = 'from-cache'")

    execute_script("Turbo.visit('#{home_path(locale: :en)}')")
    assert_no_selector ".me"
    go_back

    assert_selector ".me[data-restored=from-cache][data-worn-back='set-theme-rpg']"
    assert_selector ".me-back-opener .me-back-opener__name", text: "RPG"
    open_sheet("a.me-back-opener", "me-back-sheet")
    find("[data-key=standard] .back-picker__back").click
    assert_selector ".back-picker__tile--active[data-key=standard]"
    assert_selector ".me-back-opener .me-back-opener__name", text: "Standard", visible: :all
    find("[data-key='set-theme-rpg'] .back-picker__back").click
    assert_selector ".me-back-opener .me-back-opener__name", text: "RPG", visible: :all
    assert_equal "set-theme-rpg", Game::PlayerState.where(player_id: @player.id).pick(:active_card_back)
  end

  test "a card removed from the showcase sheet leaves the profile, the sheet sent open with the focus on the next card's remove button" do
    choose_two_cards
    sign_in_to_me
    first, second = all(".profile-showcase__slot").map { it[:"data-title"] }

    open_sheet("a.me-showcase-opener", "me-showcase-sheet")
    find("#me-showcase-sheet button[aria-label='Remove #{first} from the showcase']").click

    assert_selector "#toasts .toast", text: /#{Regexp.escape(first)} is no longer in your showcase/
    assert_modal("me-showcase-sheet")
    assert_focused "#me-showcase-sheet button[aria-label='Remove #{second} from the showcase']"
    assert_selector ".profile-showcase__slot", count: 1
    assert_equal [ second ], all("#me-showcase-sheet .me-showcase-row__title").map(&:text)
  end

  test "on a phone the settings are one tap from Me" do
    resize_to(*PHONE)
    sign_in_to_me

    find("main a.menu-item[href='/en/settings']").click

    assert_current_path settings_path(locale: :en)
  end
end
