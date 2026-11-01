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

  test "an earned title is equipped from the picker, shown with its toast, kept after a reload and removed with the no title row" do
    earn_titles
    visit home_path(locale: :en)
    click_steam_sign_in
    assert_signed_in
    visit personalization_path(locale: :en)

    assert_selector "h2", text: "PROFILE TITLE"
    assert_checked_field "No title"
    find("label", text: "Adept · Valve").click

    assert_selector ".toast", text: "TITLE EQUIPPED"
    assert_checked_field "Adept · Valve"
    visit personalization_path(locale: :en)
    assert_checked_field "Adept · Valve"

    find("label", text: "No title").click

    assert_selector ".toast", text: "TITLE REMOVED"
    assert_checked_field "No title"
  end

  test "the arrow keys move through the titles and choose each one" do
    earn_titles
    visit home_path(locale: :en)
    click_steam_sign_in
    assert_signed_in
    visit personalization_path(locale: :en)

    find_field("No title").send_keys(:arrow_down)

    assert_selector ".toast", text: "TITLE EQUIPPED"
    assert_checked_field "Adept · Valve"
  end

  test "a title not earned cannot be equipped by a forged request" do
    earn_titles
    visit home_path(locale: :en)
    click_steam_sign_in
    assert_signed_in
    visit personalization_path(locale: :en)

    execute_script(<<~JS)
      const radio = document.querySelector("input[name=title][value='adept:studio:valve']")
      radio.value = "complete:studio:valve"
      radio.click()
    JS

    assert_selector ".toast", text: "You have not earned that title."
    assert_nil Game::PlayerState.where(player_id: @player.id).pick(:active_title_rank)
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

  test "a hovered or locked back only fills the strip, and a forged choice leaves the frame where it was and says it failed" do
    Game::CardBackUnlock.record(@player.id, "set-theme-rpg", Time.current)
    sign_in_to_personalization

    find("[data-key=centurion] .back-picker__back").hover
    assert_selector ".back-picker__strip[data-showing=other]", text: /LOCKED\s+CENTURION\s+Unlock the achievement #{Regexp.escape(achievement(:boosters_100, :en))}/
    find("[data-key='etoile-dor'] .back-picker__back").click
    assert_selector ".back-picker__strip", text: "Unlock the achievement #{achievement(:first_legendary, :en)}"
    assert_selector ".back-picker__tile--active[data-key=standard]"

    execute_script(<<~JS)
      const input = document.querySelector("[data-key='set-theme-rpg'] .back-picker__form input[name=back]")
      input.value = "set-theme-horror"
      input.form.requestSubmit()
    JS

    assert_selector ".back-picker__strip[data-showing=failed]", text: "The card back could not be equipped. Try again."
    assert_selector "p[role=status]", text: "The card back could not be equipped. Try again.", visible: :all
    assert_selector ".back-picker__tile--active[data-key=standard]"
    assert_nil Game::PlayerState.where(player_id: @player.id).pick(:active_card_back)
  end

  test "each earned back says how and when it was earned, and a locked achievement back names its achievement, in English and in French" do
    set_id = insert_set([], { novice: 1, adept: 3, complete: 5 }, key: "roguelike")
    Game::SetTier.create!(player_id: @player.id, set_id:, tier: "adept", reached_by: "trade", reached_at: Time.current)
    %w[set-theme-roguelike confrere centurion].each { Game::CardBackUnlock.record(@player.id, it, Time.zone.local(2026, 10, 24, 10)) }
    Game::GoalReward.create!(player_id: @player.id, week_start: Date.new(2026, 10, 12))
    sign_in_to_personalization

    {
      en: { set: "Earned at the Adept tier of the Roguelike set · season 1", goal: "Earned by completing the mission of the week of October 12",
            centurion: "Earned with the achievement", locked: "Unlock the achievement", date: "on October 24, 2026" },
      fr: { set: "Gagné au palier Adepte du set Roguelike · saison 1", goal: "Gagné en accomplissant la mission de la semaine du 12 octobre",
            centurion: "Gagné avec le succès", locked: "Débloquez le succès", date: "le 24 octobre 2026" }
    }.each do |locale, copy|
      visit personalization_path(locale:)

      { "set-theme-roguelike" => copy[:set], "confrere" => copy[:goal], "centurion" => "#{copy[:centurion]} #{achievement(:boosters_100, locale)}" }.each do |key, sentence|
        find("[data-key='#{key}'] .back-picker__back").hover
        assert_selector ".back-picker__strip[data-showing=other] .back-picker__sentence", text: sentence, exact_text: true
        assert_selector ".back-picker__strip .back-picker__tail", text: copy[:date], exact_text: true
        assert_selector "[data-key='#{key}'] .back-picker__back[aria-label*=\"#{sentence}, #{copy[:date]}.\"]"
      end
      locked = "#{copy[:locked]} #{achievement(:first_legendary, locale)}"
      find("[data-key='etoile-dor'] .back-picker__back").hover
      assert_selector ".back-picker__strip .back-picker__sentence", text: locked, exact_text: true
      assert_selector "[data-key='etoile-dor'] .back-picker__back[aria-label$=\"#{locked}.\"]"
    end
  end

  test "a back earned in two seasons is equipped with the mark of the season pressed" do
    tiers = { novice: 1, apprentice: 2, adept: 3, complete: 5 }
    later = Catalog::Season.create!(status: :published, number: 2, published_at: Time.current)
    [ insert_set([], tiers, key: "roguelike"), insert_set([], tiers, key: "roguelike", season: later) ].each do |set_id|
      Game::SetTier.create!(player_id: @player.id, set_id:, tier: "adept", reached_by: "trade", reached_at: Time.current)
    end
    Game::CardBackUnlock.record(@player.id, "set-theme-roguelike", Time.current)
    sign_in_to_personalization

    within("[data-key='set-theme-roguelike']") do
      assert_selector ".back-picker__stamp", text: "S2"
      click_button "S1"

      assert_selector ".back-picker__season[aria-pressed=true]", text: "S1"
      assert_selector ".back-picker__stamp", text: "S1"
      assert_no_selector ".back-picker__stamp", text: "S2"
    end
    assert_selector ".back-picker__tile--active[data-key='set-theme-roguelike']"
    assert_selector "p[role=status]", text: "Card back equipped. Roguelike, with the mark of season 1, will show on your face-down cards.", visible: :all
    assert_equal [ "set-theme-roguelike", 1 ], Game::PlayerState.where(player_id: @player.id).pick(:active_card_back, :active_card_back_season)
  end

  private
    def achievement(key, locale) = "#{I18n.t("achievements.names.#{key}", locale:)} · #{I18n.t("achievements.conditions.#{key}", locale:)}"

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
