require "application_system_test_case"
require_relative "../support/catalog_seeds"
require_relative "../support/game_sets"
require_relative "../support/steam_sign_in"

# The Me page: the player's own profile, its title and card back each changed
# in a bottom sheet opened from the customize panel, its showcase edited on
# its own screen and reordered by dragging the cards of its stage, by mouse
# or by a held touch, the result shown at once.
class MePageTest < ApplicationSystemTestCase
  include CatalogSeeds
  include GameSets
  include SteamSignIn

  PHONE = [ 390, 844 ].freeze
  TITLE_OPENER = "a.me-opener[href='#me-title-sheet']"
  OPENERS = {
    TITLE_OPENER => [ "me-title-sheet", "Profile title" ],
    "a.me-back-opener" => [ "me-back-sheet", "Card back" ]
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

  SLOT = ".profile-stage__slot[data-stage-order-target=slot]"

  def slot_titles = all(SLOT, visible: :all, minimum: 2).map { it[:"data-title"] }

  def assert_hand_dealt
    eventually("the stage's cards should be dealt") do
      evaluate_script("document.querySelector('.profile-stage__fan').getAnimations({ subtree: true }).every(it => it.animationName !== 'profile-stage-deal')")
    end
  end

  # A touch only lifts the card once held, so the moves wait past the hold.
  def carry_first_slot_onto_second(pointer_type: "mouse")
    execute_script(<<~JS)
      const slots = document.querySelectorAll(#{SLOT.to_json})
      const centre = (slot) => { const box = slot.getBoundingClientRect(); return [box.left + box.width / 2, box.top + box.height / 2] }
      const [fromX, fromY] = centre(slots[0])
      const [toX, toY] = centre(slots[1])
      const pointer = (type, x, y) => new PointerEvent(type, { bubbles: true, cancelable: true, pointerId: 1, pointerType: #{pointer_type.to_json}, isPrimary: true, button: 0, clientX: x, clientY: y })
      window.letGo = () => window.dispatchEvent(pointer("pointerup", toX, toY))
      const carry = () => {
        window.dispatchEvent(pointer("pointermove", (fromX + toX) / 2, (fromY + toY) / 2))
        window.dispatchEvent(pointer("pointermove", toX, toY))
      }
      slots[0].dispatchEvent(pointer("pointerdown", fromX, fromY))
      #{pointer_type == "touch" ? "setTimeout(carry, 600)" : "carry()"}
    JS
  end

  def let_go = execute_script("window.letGo()")

  def assert_carried(title, over:)
    assert_selector "#{SLOT}[data-dragging][data-title=\"#{title}\"]"
    assert_selector "#{SLOT}.profile-stage__slot--1[data-title=\"#{over}\"]"
    assert_selector ".profile-stage__placing", text: "PLACE 2 OF 2"
  end

  test "on a phone the title and the back preview each open their sheet as a modal named by its title, Escape giving the focus back" do
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

  test "the stage's edit link opens the editor, where a tapped card joins the showcase and its count, and Done comes back to Me" do
    choose_two_cards
    portal = catalog_card_seasons(:portal_one)
    Game::Holding.create!(player_id: @player.id, card_season_id: portal.id, quantity: 1)
    sign_in_to_me

    click_on "Edit the showcase"
    assert_selector ".showcase-dock__count", text: "2/5"
    find(".showcase-pick form[action$='/cards/portal/seasons/1/showcase'] button[aria-pressed=false]").click

    assert_selector ".showcase-dock__count", text: "3/5"
    assert_selector ".showcase-pick--chosen", count: 3
    assert_selector ".showcase-dock__pick", count: 3
    click_on "Done"
    assert_selector SLOT, count: 3
  end

  test "a card carried on Me makes the other slide into its place at once, then the new order is announced without a toast and kept after a reload" do
    choose_two_cards
    sign_in_to_me
    first, second = slot_titles
    assert_hand_dealt

    carry_first_slot_onto_second
    assert_carried(first, over: second)
    assert_no_selector "#toasts .toast"
    let_go

    assert_selector "#profile-stage-status", text: "#{first} is now in place 2 of 2.", visible: :all
    assert_selector "#{SLOT}:first-child.profile-stage__slot--1[data-title=\"#{second}\"]"
    assert_no_selector "#toasts .toast"
    assert_no_selector ".profile-stage__placing", visible: true
    assert_selector ".profile-stage__name", text: /\A#{Regexp.escape(second)}\z/i
    visit me_path(locale: :en)
    assert_selector "#{SLOT}:first-child[data-title=\"#{second}\"]"
  end

  test "Escape puts a carried card back and saves nothing" do
    choose_two_cards
    sign_in_to_me
    first, second = slot_titles
    assert_hand_dealt

    carry_first_slot_onto_second
    assert_carried(first, over: second)
    find("body").send_keys(:escape)

    assert_selector "#{SLOT}.profile-stage__slot--1[data-title=\"#{first}\"]:not([data-dragging])"
    assert_no_selector ".profile-stage__placing", visible: true
    let_go
    assert_no_selector "#toasts .toast"
    assert_equal [ first, second ], Game::ChosenShowcase.call(@player).map { Catalog::CardViews.call([ it ], locale: :en)[it].title }
  end

  test "on a phone a card held then carried makes the other slide into its place, and takes it once let go" do
    choose_two_cards
    resize_to(*PHONE)
    sign_in_to_me
    first, second = slot_titles
    assert_hand_dealt

    carry_first_slot_onto_second(pointer_type: "touch")
    assert_carried(first, over: second)
    let_go

    assert_selector "#profile-stage-status", text: "#{first} is now in place 2 of 2.", visible: :all
    assert_selector "#{SLOT}:first-child[data-title=\"#{second}\"]"
  end

  test "a title chosen in its sheet shows in the band with its toast, and no title removes it" do
    earn_titles
    sign_in_to_me
    assert_selector "#{TITLE_OPENER} .me-opener__value", text: "Choose a title"

    open_sheet(TITLE_OPENER, "me-title-sheet")
    within("#me-title-sheet") { click_on "Adept · Valve" }

    assert_selector ".toast", text: "TITLE EQUIPPED"
    assert_selector ".profile-band .profile-band__title", text: "Adept · Valve"
    assert_no_selector "dialog#me-title-sheet", visible: true

    open_sheet(TITLE_OPENER, "me-title-sheet")
    assert_selector "#me-title-sheet button[aria-current=true]", text: /\AAdept · Valve\z/i
    within("#me-title-sheet") { click_on "No title" }

    assert_selector ".toast", text: "TITLE REMOVED"
    assert_selector "#{TITLE_OPENER} .me-opener__value", text: "Choose a title"
  end

  test "a back equipped in its sheet shows in the band's preview at once, the page kept" do
    Game::CardBackUnlock.record(@player.id, "set-theme-rpg", Time.current)
    sign_in_to_me
    assert_selector ".me-back-opener [data-me-target=preview] .me-opener__value", text: "Standard"
    execute_script("window.stayedOnPage = true")

    open_sheet("a.me-back-opener", "me-back-sheet")
    find("[data-key='set-theme-rpg'] .back-picker__back").click

    assert_selector ".back-picker__tile--active[data-key='set-theme-rpg']"
    assert_selector "p[role=status]", text: "Card back equipped. RPG will show on your face-down cards.", visible: :all
    assert_selector ".me-back-opener [data-me-target=preview] .me-opener__value", text: "RPG", visible: :all
    assert_selector ".me[data-worn-back='set-theme-rpg']"
    assert evaluate_script("window.stayedOnPage")
    assert_equal "set-theme-rpg", Game::PlayerState.where(player_id: @player.id).pick(:active_card_back)

    page.send_keys(:escape)
    assert_selector ".me-back-opener .me-opener__value", text: "RPG"
    visit me_path(locale: :en)
    assert_selector ".me-back-opener .me-opener__value", text: "RPG"
  end

  test "a back equipped on Me stays in the preview once the page is restored from the cache by Back, and equipping goes on from there" do
    Game::CardBackUnlock.record(@player.id, "set-theme-rpg", Time.current)
    sign_in_to_me
    open_sheet("a.me-back-opener", "me-back-sheet")
    find("[data-key='set-theme-rpg'] .back-picker__back").click
    assert_selector ".me-back-opener .me-opener__value", text: "RPG", visible: :all
    execute_script("document.querySelector('.me').dataset.restored = 'from-cache'")

    execute_script("Turbo.visit('#{home_path(locale: :en)}')")
    assert_no_selector ".me"
    go_back

    assert_selector ".me[data-restored=from-cache][data-worn-back='set-theme-rpg']"
    assert_selector ".me-back-opener .me-opener__value", text: "RPG"
    open_sheet("a.me-back-opener", "me-back-sheet")
    find("[data-key=standard] .back-picker__back").click
    assert_selector ".back-picker__tile--active[data-key=standard]"
    assert_selector ".me-back-opener .me-opener__value", text: "Standard", visible: :all
    find("[data-key='set-theme-rpg'] .back-picker__back").click
    assert_selector ".me-back-opener .me-opener__value", text: "RPG", visible: :all
    assert_equal "set-theme-rpg", Game::PlayerState.where(player_id: @player.id).pick(:active_card_back)
  end

  test "on a phone the header menu leads to the settings" do
    resize_to(*PHONE)
    sign_in_to_me

    find(".player-chip__button").click
    within("#player-menu") { click_link href: "/en/settings" }

    assert_current_path settings_path(locale: :en)
  end
end
