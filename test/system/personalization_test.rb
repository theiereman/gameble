require "application_system_test_case"
require_relative "../support/catalog_seeds"
require_relative "../support/game_sets"
require_relative "../support/steam_sign_in"

class PersonalizationTest < ApplicationSystemTestCase
  include CatalogSeeds
  include GameSets
  include SteamSignIn

  setup do
    @player = accounts_players(:player)
    mock_steam_sign_in(@player.steam_id)
  end

  test "a card is moved from the keyboard, the focus staying on the moved card's button" do
    choose_two_cards
    visit personalization_path(locale: :fr)
    labels = all(".profile-showcase__slot .card-link").map { it[:"aria-label"] }

    find(".profile-showcase__slot:first-child form[data-direction='later'] button").send_keys(:enter)

    assert_selector ".profile-showcase__slot:first-child .card-link[aria-label=\"#{labels.last}\"]"
    assert_selector ".profile-showcase__slot:last-child form[data-direction='earlier'] button:focus"
  end

  test "a dragged card is announced in a polite status once the new order is saved" do
    choose_two_cards
    visit personalization_path(locale: :en)
    first_title = all(".profile-showcase__slot").first[:"data-title"]

    drag_first_slot_onto_last

    assert_selector "p[role=status]", text: "#{first_title} is now in place 2 of 2.", visible: :all
    assert_selector ".profile-showcase__slot:last-child[data-title=\"#{first_title}\"]"
    visit personalization_path(locale: :en)
    assert_selector ".profile-showcase__slot:last-child[data-title=\"#{first_title}\"]"
  end

  test "an earned title is chosen in the menu, shown with its toast, kept after a reload and removed with the no title option" do
    earn_titles
    visit home_path(locale: :en)
    click_steam_sign_in
    assert_signed_in
    visit personalization_path(locale: :en)

    assert_selector "h2", text: "PROFILE TITLE"
    assert_selector :select, "title", selected: "No title"
    select "Adept · Valve", from: "title"

    assert_selector ".toast", text: "TITLE EQUIPPED"
    assert_selector :select, "title", selected: "Adept · Valve"
    visit personalization_path(locale: :en)
    assert_selector :select, "title", selected: "Adept · Valve"

    select "No title", from: "title"

    assert_selector ".toast", text: "TITLE REMOVED"
    assert_selector :select, "title", selected: "No title"
  end

  test "an unlocked card back is equipped in one click, in place and announced, the focus staying on it, and kept after a reload" do
    Game::CardBackUnlock.record(@player.id, "set-theme-rpg", Time.current)
    sign_in_to_personalization

    assert_selector "h2", text: "CARD BACK"
    assert_selector ".back-picker__strip[data-showing=active] .back-picker__name", text: "STANDARD"
    execute_script("window.stayedOnPage = true")
    find("[data-key='set-theme-rpg'] .back-picker__back").click

    assert_selector ".back-picker__tile--active[data-key='set-theme-rpg'] .back-picker__plate", text: "ACTIVE"
    assert_no_selector ".back-picker__tile--active[data-key=standard]"
    assert_selector "p[role=status]", text: "Card back equipped. RPG will show on your face-down cards.", visible: :all
    assert_selector "[data-key='set-theme-rpg'] .back-picker__back:focus"
    assert_selector ".back-picker__strip[data-showing=active]", text: /ACTIVE\s+RPG/
    assert_selector "[data-key='set-theme-rpg'] .back-picker__back[aria-label^='RPG, active.']"
    assert_selector "[data-key=standard] .back-picker__back[aria-label$='Equip.']"
    assert_no_selector ".toast", text: /EQUIPPED/
    assert evaluate_script("window.stayedOnPage")
    assert_equal "set-theme-rpg", Game::PlayerState.where(player_id: @player.id).pick(:active_card_back)

    visit personalization_path(locale: :en)
    assert_selector ".back-picker__tile--active[data-key='set-theme-rpg']"
  end

  test "a back equipped in place stays the active one once the page is restored from the cache by Back, and equipping goes on from there" do
    Game::CardBackUnlock.record(@player.id, "set-theme-rpg", Time.current)
    sign_in_to_personalization
    find("[data-key='set-theme-rpg'] .back-picker__back").click
    assert_selector ".back-picker__tile--active[data-key='set-theme-rpg']"
    execute_script("document.querySelector('.back-picker').dataset.restored = 'from-cache'")

    execute_script("Turbo.visit('#{home_path(locale: :en)}')")
    assert_no_selector ".back-picker"
    go_back

    assert_selector ".back-picker[data-restored=from-cache]"
    assert_selector ".back-picker__strip[data-showing=active]", text: /ACTIVE\s+RPG/
    find("[data-key=standard] .back-picker__back").click
    assert_selector ".back-picker__tile--active[data-key=standard]"
    find("[data-key='set-theme-rpg'] .back-picker__back").click
    assert_selector ".back-picker__tile--active[data-key='set-theme-rpg']"
    assert_selector ".back-picker__tile--active", count: 1
    assert_equal "set-theme-rpg", Game::PlayerState.where(player_id: @player.id).pick(:active_card_back)
  end

  private

    def sign_in_to_personalization
      visit home_path(locale: :en)
      click_steam_sign_in
      assert_signed_in
      visit personalization_path(locale: :en)
    end

    def earn_titles
      season, cards = published_cards(5)
      set_id = insert_set(cards, { novice: 1, adept: 3, complete: 5 }, kind: "studio", key: "valve", params: { "studio" => "Valve" }, season:)
      Game::SetTier.insert_all!(%w[novice adept].map { |tier| { player_id: @player.id, set_id:, tier:, reached_by: "trade", reached_at: Time.current } })
    end

    def choose_two_cards
      [ catalog_card_seasons(:common_card_one), catalog_card_seasons(:rare_card_one) ].each do |card|
        Game::Holding.create!(player_id: @player.id, card_season_id: card.id, quantity: 1)
        Game::AddToShowcase.new.call(player: @player, card_season_id: card.id).value!
      end
      visit home_path(locale: :en)
      click_steam_sign_in
      assert_signed_in
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
end
