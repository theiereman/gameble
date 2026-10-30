require "application_system_test_case"
require_relative "../support/catalog_seeds"
require_relative "../support/game_sets"
require_relative "../support/steam_sign_in"

class ProfileEditingTest < ApplicationSystemTestCase
  include CatalogSeeds
  include GameSets
  include SteamSignIn

  setup do
    @player = accounts_players(:player)
    mock_steam_sign_in(@player.steam_id)
  end

  test "the top bar's avatar opens the own profile, whose gear opens the settings" do
    Game::Holding.create!(player_id: @player.id, card_season_id: catalog_card_seasons(:common_card_one).id, quantity: 1)
    Game::AddToShowcase.new.call(player: @player, card_season_id: catalog_card_seasons(:common_card_one).id).value!
    visit home_path(locale: :en)
    click_steam_sign_in
    assert_signed_in

    find(".player-chip__button").click

    assert_current_path brother_path(locale: :en, token: @player.token)
    assert_selector ".profile-showcase .card"
    assert_selector ".profile-pen", minimum: 2

    find(".profile-band__settings").click

    assert_selector "h1", text: "SETTINGS"
    assert_no_selector ".profile-showcase"
  end

  test "the player reorders and removes showcase cards on their own profile" do
    [ catalog_card_seasons(:common_card_one), catalog_card_seasons(:rare_card_one) ].each do |card|
      Game::Holding.create!(player_id: @player.id, card_season_id: card.id, quantity: 1)
      Game::AddToShowcase.new.call(player: @player, card_season_id: card.id).value!
    end
    visit home_path(locale: :en)
    click_steam_sign_in
    assert_signed_in
    visit own_profile

    labels = all(".profile-showcase__slot .card-link").map { it[:"aria-label"] }
    within(".profile-showcase__slot:first-child") { find("form[data-direction='later'] button").click }

    assert_selector ".profile-showcase__slot:first-child .card-link[aria-label=\"#{labels.last}\"]"

    within(".profile-showcase__slot:first-child") { find("button[aria-label^='Remove']").click }

    assert_selector ".profile-showcase__slot", count: 1
    assert_selector ".profile-showcase__slot .card-link[aria-label=\"#{labels.first}\"]"
  end

  test "a card is moved from the keyboard, the focus stays on the moved card's button and the order shows on the French profile and hub" do
    choose_two_cards
    visit own_profile(:fr)
    labels = all(".profile-showcase__slot .card-link").map { it[:"aria-label"] }
    slugs = card_slugs

    find(".profile-showcase__slot:first-child form[data-direction='later'] button").send_keys(:enter)

    assert_selector ".profile-showcase__slot:first-child .card-link[aria-label=\"#{labels.last}\"]"
    assert_selector ".profile-showcase__slot:last-child form[data-direction='earlier'] button:focus"

    visit brother_path(locale: :fr, token: @player.token)
    assert_selector ".profile-showcase__slot:first-child .card-link[aria-label=\"#{labels.last}\"]"

    visit home_path(locale: :fr)
    assert_selector ".hub-showcase__actions a[href*='/#{slugs.last}/']"
  end

  test "a dragged card is announced in a polite status once the new order is saved" do
    choose_two_cards
    visit own_profile
    first_title = all(".profile-showcase__slot").first[:"data-title"]

    drag_first_slot_onto_last

    assert_selector "p[role=status]", text: "#{first_title} is now in place 2 of 2.", visible: :all
    assert_selector ".profile-showcase__slot:last-child[data-title=\"#{first_title}\"]"
    visit own_profile
    assert_selector ".profile-showcase__slot:last-child[data-title=\"#{first_title}\"]"
  end

  test "removing a card shows a toast and puts the focus on the next card's remove button, then on the heading" do
    choose_two_cards
    visit own_profile
    remaining = all(".profile-showcase__slot .card-link").last[:"aria-label"]

    find(".profile-showcase__slot:first-child button[aria-label^='Remove']").send_keys(:enter)

    assert_selector "#toasts", text: "REMOVED FROM SHOWCASE"
    assert_selector ".profile-showcase__slot", count: 1
    assert_selector ".profile-showcase__slot .card-link[aria-label=\"#{remaining}\"]"
    assert_selector ".profile-showcase__slot button[aria-label^='Remove']:focus"

    find(".profile-showcase__slot button[aria-label^='Remove']").send_keys(:enter)

    assert_no_selector ".profile-showcase"
    assert_selector "h2#profile-showcase-heading:focus"
  end

  test "the own showcase carries its information mark" do
    choose_two_cards
    visit own_profile

    assert_selector "section.profile-section h2.profile-section__title", text: "SHOWCASE"
    find(".profile-showcase__info-mark").click
    assert_selector ".profile-showcase__info-text", text: /cross/
  end

  test "a card of the own showcase opens its detail with the way back to the profile" do
    choose_two_cards
    visit own_profile

    find(".profile-showcase__slot:first-child .card-link").click

    assert_current_path(/\/cards\/.+\?brother=#{@player.token}\z/)
    assert_selector "a.top-bar__phone-back[href='#{own_profile}']", visible: :all
  end

  test "an earned title is equipped from the picker, shown with its toast, kept after a reload and removed with the no title row" do
    earn_titles
    visit home_path(locale: :en)
    click_steam_sign_in
    assert_signed_in
    visit own_profile
    open_dialog "Choose your title"

    assert_selector "dialog h2", text: "PROFILE TITLE"
    assert_checked_field "No title"
    find("label", text: "Adept · Valve").click

    assert_selector ".toast", text: "TITLE EQUIPPED"
    assert_selector ".profile-band__title", text: "Adept · Valve"
    visit own_profile
    open_dialog "Choose your title"
    assert_checked_field "Adept · Valve"

    find("label", text: "No title").click

    assert_selector ".toast", text: "TITLE REMOVED"
    assert_selector ".profile-band__placeholder", text: "No title"
  end

  test "the arrow keys move through the titles and choose each one" do
    earn_titles
    visit home_path(locale: :en)
    click_steam_sign_in
    assert_signed_in
    visit own_profile
    open_dialog "Choose your title"

    find_field("No title", visible: :all).send_keys(:arrow_down)

    assert_selector ".toast", text: "TITLE EQUIPPED"
    assert_selector ".profile-band__title", text: "Adept · Valve"
  end

  test "a title not earned cannot be equipped by a forged request" do
    earn_titles
    visit home_path(locale: :en)
    click_steam_sign_in
    assert_signed_in
    visit own_profile
    open_dialog "Choose your title"

    execute_script(<<~JS)
      const radio = document.querySelector("input[name=title][value='adept:studio:valve']")
      radio.value = "complete:studio:valve"
      radio.click()
    JS

    assert_selector ".toast", text: "You have not earned that title."
    assert_nil Game::PlayerState.where(player_id: @player.id).pick(:active_title_rank)
  end

  test "an unlocked card back is equipped with its preview and toast and kept after a reload" do
    Game::CardBackUnlock.record(@player.id, "set-theme-rpg", Time.current)
    sign_in_to_own_profile

    assert_selector ".profile-band__back", text: "Card back: Standard"
    open_dialog "Choose your card back"
    assert_selector "dialog h2", text: "CARD BACK"
    assert_selector ".back-picker__preview-name", text: "Standard"
    within(".back-picker__tile", text: "RPG") { click_button }

    assert_selector ".toast", text: "CARD BACK EQUIPPED"
    assert_selector ".profile-band__back", text: "Card back: RPG"
    visit own_profile
    open_dialog "Choose your card back"
    assert_selector ".back-picker__preview-name", text: "RPG"
    assert_selector ".back-picker__tile--active", text: "RPG"
  end

  test "a locked card back states its condition and cannot be equipped, even by a forged request" do
    Game::CardBackUnlock.record(@player.id, "set-theme-rpg", Time.current)
    sign_in_to_own_profile
    open_dialog "Choose your card back"

    assert_selector ".back-picker__tile--locked", text: "Collect half of the Horror set."
    within(".back-picker__tile--locked", text: "Horror") { click_button }

    assert_selector ".toast", text: "This card back is still locked."
    execute_script(<<~JS)
      const input = document.querySelector(".back-picker__form input[name=back][value='set-theme-rpg']")
      input.value = "set-theme-horror"
      input.form.requestSubmit()
    JS

    assert_selector ".toast", text: "This card back is still locked.", count: 2
    assert_nil Game::PlayerState.where(player_id: @player.id).pick(:active_card_back)
  end

  private
    def own_profile(locale = :en) = brother_path(locale:, token: @player.token)

    def open_dialog(pen_label)
      find("button.profile-pen[aria-label='#{pen_label}']").click
      assert_selector "dialog[open]"
    end

    def sign_in_to_own_profile
      visit home_path(locale: :en)
      click_steam_sign_in
      assert_signed_in
      visit own_profile
    end

    def earn_titles
      season, cards = published_cards(5)
      set_id = insert_set(cards, { novice: 1, adept: 3, complete: 5 }, kind: "studio", key: "valve", params: { "studio" => "Valve" }, season:)
      Game::SetTier.insert_all!(%w[novice adept].map { |tier| { player_id: @player.id, set_id:, tier:, reached_by: "trade", reached_at: Time.current } })
    end

    def assert_checked_field(label)
      assert_field label, type: :radio, checked: true, visible: :all
    end

    def card_slugs
      all(".profile-showcase__slot .card-link", visible: :all).map { it[:href][%r{/cards/([^/]+)/}, 1] }
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
