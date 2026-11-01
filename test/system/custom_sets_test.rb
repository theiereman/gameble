require "application_system_test_case"
require_relative "../support/catalog_seeds"
require_relative "../support/game_sets"
require_relative "../support/steam_sign_in"

# A player's own set: the editor from the collection and from the album, its
# search, chips, picks and refusals; ANNULER discarding; the delete dialog;
# MES SETS gives way to a set search and never shows on a public profile.
class CustomSetsTest < ApplicationSystemTestCase
  include CatalogSeeds
  include GameSets
  include SteamSignIn

  setup do
    @player = accounts_players(:player)
    @season, @cards = published_cards(5)
  end

  def sign_in(player)
    mock_steam_sign_in(player.steam_id)
    visit home_path(locale: :en)
    click_steam_sign_in
    assert_signed_in
  end

  def title(index) = Catalog::CardText.find_by!(card_id: Catalog::CardSeason.find(@cards[index]).card_id, locale: "en").title

  def editor = find("dialog#custom-set-editor[open]")

  def toggle_of(title) = find(".custom-set-game__toggle[aria-label^='#{title},']")

  def chip(label) = find(".custom-set-editor__chips .filter-chip", text: label)

  def assert_refusal(text) = assert_selector("#custom-set-editor-refusal", text:)

  def assert_no_refusal = assert_selector("#custom-set-editor-refusal:empty", visible: :all)

  def shown_titles = all(".custom-set-game .card__title").map { it.text.downcase }

  def create_set(name: "Mes favoris", cards: @cards.first(3))
    Game::CreateCustomSet.new.call(player: @player, name:, card_ids: Catalog::CardSeason.where(id: cards).order(:id).pluck(:card_id)).value!
  end

  test "a player names a set, searches and picks three games, one not owned, saves, and finds it in MES SETS" do
    hold_all(@player, [ @cards[1] ])
    sign_in(@player)
    visit library_path(locale: :en)

    within("section.custom-sets") do
      assert_text "Visible to you only · 0 / 10"
      find("button.new-set-tile", text: /new set\s+3 to 50 games · 10 sets at most/i).click
    end
    within(editor) do
      assert_selector ".modal__title", text: /\Anew set\z/i
      assert_selector "#custom-set-name:focus"
      fill_in "Set name", with: "Mes favoris"
      assert_selector "#custom-set-name-count", text: "11 / 40"
      fill_in "Search a game", with: "Seed"
      assert_selector ".custom-set-game", count: 5
      chip(/\Aowned\z/i).click
      assert_selector ".custom-set-game", count: 1
      assert_selector ".custom-set-game__toggle[aria-label='#{title(1)}, owned']"
      chip(/\Aall\z/i).click
      assert_selector ".custom-set-game", count: 5

      toggle_of(title(0)).click
      assert_selector ".custom-set-game__toggle[aria-label='#{title(0)}, not owned, in the set'][aria-pressed=true]"
      toggle_of(title(0)).send_keys(:arrow_right)
      assert_selector ".custom-set-game__toggle[aria-label^='#{title(1)},'][tabindex='0']:focus"
      toggle_of(title(1)).send_keys(:space)
      toggle_of(title(2)).click
      assert_selector ".custom-set-editor__count b", text: "3 games"
      assert_selector ".filter-chip", text: /\Aselected · 3\z/i
      chip(/selected/i).click
      assert_selector ".custom-set-game", count: 3
      assert_equal [ 0, 1, 2 ].map { title(it).downcase }, shown_titles
      take_screenshot
      click_on "Save"
    end

    assert_no_selector "dialog[open]"
    assert_current_path library_path(locale: :en)
    within("section.custom-sets") do
      assert_text "Visible to you only · 1 / 10"
      assert_selector "li:first-child > a.set-tile .set-tile__face--recto .set-tile__head", text: /Mes favoris\s+custom set · 3 games\s+1\/3/i
      assert_selector "li:last-child > button.new-set-tile"
    end
    take_screenshot
  end

  test "the author edits the set from MODIFIER: takes a game out, adds two, renames it, and lands on its album" do
    custom_set = create_set
    sign_in(@player)
    visit custom_set_path(locale: :en, token: custom_set.token)

    click_on "Edit"
    within(editor) do
      assert_selector ".modal__title", text: /\Aedit the set\z/i
      assert_field "Set name", with: "Mes favoris"
      chip(/\Aselected · 3\z/i).click
      assert_selector ".custom-set-game", count: 3
      assert_equal [ 0, 1, 2 ].map { title(it).downcase }, shown_titles
      toggle_of(title(1)).click
      chip(/\Aall\z/i).click
      fill_in "Search a game", with: "Seed"
      assert_selector ".custom-set-game", count: 5
      toggle_of(title(3)).click
      toggle_of(title(4)).click
      assert_selector ".custom-set-editor__count b", text: "4 games"
      fill_in "Set name", with: "Jeux du soir"
      click_on "Save"
    end

    assert_selector "h1#set-album-heading", text: /\Ajeux du soir\z/i
    assert_no_selector "dialog[open]"
    assert_selector ".set-album__grid > li", count: 4
    assert_equal [ 0, 2, 3, 4 ].map { title(it).downcase }, all(".set-album__grid .card__title").map { it.text.downcase }
  end

  test "ANNULER, the close button or Esc discards the editor's changes and gives the focus back" do
    custom_set = create_set
    sign_in(@player)
    visit custom_set_path(locale: :en, token: custom_set.token)

    [ -> { click_on "Cancel" }, -> { find(".modal__close").click }, -> { find_field("Set name").send_keys(:escape) } ].each do |discard|
      click_on "Edit"
      within(editor) do
        fill_in "Set name", with: "Autre chose"
        fill_in "Search a game", with: "Seed"
        assert_selector ".custom-set-game", count: 5
        toggle_of(title(3)).click
        assert_selector ".custom-set-editor__count b", text: "4 games"
        discard.call
      end
      assert_no_selector "dialog[open]"
      assert_selector ".set-album__actions button[data-dialog-opener-dialog-value=custom-set-editor]:focus"

      click_on "Edit"
      within(editor) do
        assert_field "Set name", with: "Mes favoris"
        assert_field "Search a game", with: ""
        assert_selector "#custom-set-name-count", text: "11 / 40"
        assert_selector ".custom-set-editor__count b", text: "3 games"
        assert_selector ".custom-set-game", minimum: 6
        assert_selector ".custom-set-game__toggle[aria-label^='#{title(3)},'][aria-pressed=false]"
        click_on "Cancel"
      end
    end
    assert_equal "Mes favoris", custom_set.reload.name
  end

  test "SUPPRIMER asks first: ANNULER keeps the set and returns to the button, SUPPRIMER deletes it with a toast" do
    custom_set = create_set(name: "Jeux du soir")
    sign_in(@player)
    visit custom_set_path(locale: :en, token: custom_set.token)

    click_on "Delete"
    within("dialog#delete-custom-set[open]") do
      assert_selector ".modal__title", text: /\Adelete “jeux du soir”\?\z/i
      assert_text "Your cards stay in your collection."
      click_on "Cancel"
    end
    assert_no_selector "dialog[open]"
    assert_selector ".set-album__actions button[data-dialog-opener-dialog-value=delete-custom-set]:focus"

    click_on "Delete"
    within("dialog#delete-custom-set[open]") { click_on "Delete" }

    assert_selector "#toasts .toast", text: /Set deleted/i
    assert_selector "#toasts .toast", text: "“Jeux du soir” is no longer one of your sets."
    assert_current_path library_path(locale: :en)
    assert_no_selector "section.custom-sets a.set-tile"
    assert_text "Visible to you only · 0 / 10"
  end

  test "at fifty games one more is refused in the editor: nothing is added and the refusal shows" do
    _season, more = published_cards(45)
    custom_set = create_set(cards: @cards + more)
    sign_in(@player)
    visit custom_set_path(locale: :en, token: custom_set.token)

    click_on "Edit"
    within(editor) do
      assert_selector ".custom-set-editor__count b", text: "50 games"
      fill_in "Search a game", with: "Portal"
      assert_selector ".custom-set-game", count: 1
      toggle_of("Portal").click
      assert_refusal(/\A50 games at most · Remove a game to add another\.\z/i)
      assert_selector ".custom-set-game__toggle[aria-label='Portal, not owned'][aria-pressed=false]"
      assert_selector ".custom-set-editor__count b", text: "50 games"
      take_screenshot
      fill_in "Search a game", with: ""
      chip(/\Aselected · 50\z/i).click
      assert_selector ".custom-set-game", count: 48
      click_on "Load more"
      assert_selector ".custom-set-editor__grid", count: 1
      assert_selector ".custom-set-editor__grid > .custom-set-game", count: 50
      assert_selector ".custom-set-editor__grid > .custom-set-game:nth-child(49) .custom-set-game__toggle[tabindex='0']:focus"
      first(".custom-set-game__toggle").click
      assert_selector ".custom-set-editor__count b", text: "49 games"
      assert_no_refusal
    end
  end

  test "under three games, with an empty name or at ten sets saved elsewhere, ENREGISTRER shows the refusal and saves nothing" do
    sign_in(@player)
    visit library_path(locale: :en)

    find("button.new-set-tile").click
    within(editor) do
      fill_in "Set name", with: "Mes favoris"
      fill_in "Search a game", with: "Seed"
      assert_selector ".custom-set-game", count: 5
      toggle_of(title(0)).click
      toggle_of(title(1)).click
      click_on "Save"
      assert_refusal(/\A3 games at least · Add 1 more game to save the set\.\z/i)
      assert_selector ".custom-set-editor__count b", text: "2 games"

      toggle_of(title(2)).click
      assert_no_refusal
      fill_in "Set name", with: " "
      click_on "Save"
      assert_refusal(/\Aname required · Give your set a name\.\z/i)

      fill_in "Set name", with: "Mes favoris"
      10.times { create_set(name: "Ailleurs #{it}") }
      click_on "Save"
      assert_refusal(/\A10 sets at most · Remove a set to create another\.\z/i)
      assert_selector ".custom-set-editor__count b", text: "3 games"
    end
    assert_current_path library_path(locale: :en)
    assert_equal 10, Game::CustomSet.where(player_id: @player.id).count
  end

  test "on the phone the editor is a full-height sheet, its refusal in French above its two buttons sharing a row" do
    sign_in(@player)
    resize_to(390, 844)
    visit library_path(locale: :fr)

    find("button.new-set-tile").click
    within(editor) do
      fill_in "Nom du set", with: "Mes favoris"
      click_on "Enregistrer"
      assert_refusal(/\A3 jeux au moins · Ajoutez encore 3 jeux pour enregistrer le set\.\z/i)
      assert_selector ".custom-set-editor__count b", text: "0 jeu"
    end
    eventually("the sheet should fill the screen, the refusal above two 48px buttons on one row") do
      sheet = page.evaluate_script(<<~JS)
        (() => {
          const box = (selector) => document.querySelector(selector).getBoundingClientRect()
          const [cancel, save] = [...document.querySelectorAll(".custom-set-editor__actions .button")].map((button) => button.getBoundingClientRect())
          return { height: box("#custom-set-editor").height, viewport: window.innerHeight, refusalBottom: box("#custom-set-editor-refusal").bottom,
                   buttonsTop: cancel.top, sameRow: Math.abs(cancel.top - save.top) < cancel.height / 2, buttonHeight: save.height,
                   columns: [...document.querySelectorAll(".custom-set-editor__grid")].map((grid) => getComputedStyle(grid).gridTemplateColumns.split(" ").length)[0] }
        })()
      JS
      sheet["height"] == sheet["viewport"] && sheet["refusalBottom"] <= sheet["buttonsTop"] && sheet["sameRow"] &&
        sheet["buttonHeight"] == 48 && sheet["columns"] == 2
    end
    take_screenshot
    assert_equal 0, Game::CustomSet.where(player_id: @player.id).count
  end

  test "a typed set search hides MES SETS as it hides EN COURS; a public profile's collection has no MES SETS" do
    insert_theme(@cards, key: "roguelike", season: @season)
    create_set
    sign_in(@player)
    visit library_path(locale: :en)
    assert_selector "section.custom-sets", visible: true

    fill_in "set-search-field", with: "rogue"
    assert_selector ".set-results"
    assert_no_selector "section.custom-sets", visible: true

    fill_in "set-search-field", with: ""
    assert_selector "section.custom-sets", visible: true

    visit brother_collection_path(locale: :en, token: @player.token)
    assert_selector ".collection .collection-grid"
    assert_no_selector ".custom-sets"
    assert_no_text "Mes favoris"
  end

  test "a typed set search finds a custom set in place of every section, which come back once it is cleared" do
    insert_theme(@cards, key: "roguelike", season: @season)
    hold_all(@player, @cards.first(2))
    create_set
    sign_in(@player)
    visit library_path(locale: :en)
    assert_selector "#set-entry-in-progress a.set-tile"

    fill_in "set-search-field", with: "favo"
    within(".set-results") do
      assert_selector "a.set-tile[href='#{custom_set_path(locale: :en, token: Game::CustomSet.sole.token)}']", count: 1
      assert_selector "a.set-tile .set-tile__face--recto .set-tile__name", text: "Mes favoris"
    end
    assert_selector ".set-search__status", text: "1 set found"
    [ "#goals", "section.custom-sets", "#set-entry-in-progress" ].each { assert_no_selector it, visible: true }

    fill_in "set-search-field", with: ""
    assert_no_selector ".set-results"
    [ "#goals", "section.custom-sets", "#set-entry-in-progress" ].each { assert_selector it, visible: true }
  end

  test "on the phone MES SETS shows two sets and the new set tile, and Tout voir unfolds the others in place, focusing the third" do
    4.times { create_set(name: "Set #{it}") }
    sign_in(@player)
    visit library_path(locale: :fr)
    within("section.custom-sets") do
      assert_selector "a.set-tile", count: 4
      assert_no_selector ".custom-sets__unfold"
    end

    resize_to(390, 844)
    within("section.custom-sets") do
      assert_selector "a.set-tile", count: 2
      assert_equal [ "Set 0", "Set 1" ], all("a.set-tile .set-tile__face--recto .set-tile__name").map(&:text)
      eventually("the new set tile should be a 120px row, its 44px square beside its text") do
        tile = page.evaluate_script(<<~JS)
          (() => {
            const box = (selector) => document.querySelector(selector).getBoundingClientRect()
            return { height: box(".new-set-tile").height, square: box(".new-set-tile__plus").width, besides: box(".new-set-tile__text").left > box(".new-set-tile__plus").right }
          })()
        JS
        tile["height"] == 120 && tile["square"] == 44 && tile["besides"]
      end
      take_screenshot
      find(".custom-sets__unfold", text: /\Aet 2 autres sets · tout voir\z/i).click
      assert_selector "a.set-tile", count: 4
      assert_no_selector ".custom-sets__unfold"
      assert_selector "ul.custom-sets__tiles > li:nth-child(3) > a.set-tile:focus"
      assert_selector "ul.custom-sets__tiles > li:last-child > button.new-set-tile"
    end
  end
end
