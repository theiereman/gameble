require "application_system_test_case"
require_relative "../support/steam_sign_in"

class PersonalizationTest < ApplicationSystemTestCase
  include SteamSignIn

  setup do
    @player = accounts_players(:player)
    mock_steam_sign_in(@player.steam_id)
  end

  test "the player menu opens Personalization, which holds the showcase the settings no longer show" do
    Game::Holding.create!(player_id: @player.id, card_season_id: catalog_card_seasons(:common_card_one).id, quantity: 1)
    Game::AddToShowcase.new.call(player: @player, card_season_id: catalog_card_seasons(:common_card_one).id).value!
    visit home_path(locale: :en)
    click_steam_sign_in
    assert_signed_in

    find(".player-chip__button").click
    click_link "Personalization"

    assert_selector "h1", text: "PERSONALIZATION"
    assert_selector ".profile-showcase .card"

    visit settings_path(locale: :en)

    assert_selector "h1", text: "PROFILE AND SETTINGS"
    assert_no_selector ".profile-showcase"
  end

  test "the player reorders and removes showcase cards on Personalization" do
    [ catalog_card_seasons(:common_card_one), catalog_card_seasons(:rare_card_one) ].each do |card|
      Game::Holding.create!(player_id: @player.id, card_season_id: card.id, quantity: 1)
      Game::AddToShowcase.new.call(player: @player, card_season_id: card.id).value!
    end
    visit home_path(locale: :en)
    click_steam_sign_in
    assert_signed_in
    visit personalization_path(locale: :en)

    labels = all(".profile-showcase__slot .card-link").map { it[:"aria-label"] }
    within(".profile-showcase__slot:first-child") { find("form[data-direction='later'] button").click }

    assert_selector ".profile-showcase__slot:first-child .card-link[aria-label=\"#{labels.last}\"]"

    within(".profile-showcase__slot:first-child") { find("button[aria-label^='Remove']").click }

    assert_selector ".profile-showcase__slot", count: 1
    assert_selector ".profile-showcase__slot .card-link[aria-label=\"#{labels.first}\"]"
  end

  test "a card is moved from the keyboard, the focus stays on the moved card's button and the order shows on the French profile and hub" do
    choose_two_cards
    visit personalization_path(locale: :fr)
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
    visit personalization_path(locale: :en)
    first_title = all(".profile-showcase__slot").first[:"data-title"]

    drag_first_slot_onto_last

    assert_selector "p[role=status]", text: "#{first_title} is now in place 2 of 2.", visible: :all
    assert_selector ".profile-showcase__slot:last-child[data-title=\"#{first_title}\"]"
    visit personalization_path(locale: :en)
    assert_selector ".profile-showcase__slot:last-child[data-title=\"#{first_title}\"]"
  end

  test "removing a card shows a toast and puts the focus on the next card's remove button, then on the heading" do
    choose_two_cards
    visit personalization_path(locale: :en)
    remaining = all(".profile-showcase__slot .card-link").last[:"aria-label"]

    find(".profile-showcase__slot:first-child button[aria-label^='Remove']").send_keys(:enter)

    assert_selector "#toasts", text: "REMOVED FROM SHOWCASE"
    assert_selector ".profile-showcase__slot", count: 1
    assert_selector ".profile-showcase__slot .card-link[aria-label=\"#{remaining}\"]"
    assert_selector ".profile-showcase__slot button[aria-label^='Remove']:focus"

    find(".profile-showcase__slot button[aria-label^='Remove']").send_keys(:enter)

    assert_no_selector ".profile-showcase"
    assert_selector "h2#personalization-showcase-heading:focus"
  end

  test "the showcase takes the same panel as the other sections, with its information mark" do
    choose_two_cards
    visit personalization_path(locale: :en)

    assert_selector "section.panel.personalization-section h2.personalization-section__title", text: "SHOWCASE"
    find(".profile-showcase__info-mark").click
    assert_selector ".profile-showcase__info-text", text: /cross/
  end

  test "a card of the page opens its detail with the way back to Personalization" do
    choose_two_cards
    visit personalization_path(locale: :en)

    find(".profile-showcase__slot:first-child .card-link").click

    assert_current_path(/\/cards\/.+\?from=personalization\z/)
    assert_selector "a.top-bar__phone-back[href='#{personalization_path(locale: :en)}']", visible: :all
  end

  private
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
