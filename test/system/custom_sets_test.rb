require "application_system_test_case"
require_relative "../support/catalog_seeds"
require_relative "../support/game_sets"
require_relative "../support/steam_sign_in"

# A player's own set: the editor from the collection and from the album, its
# search, chips, picks and limit; ANNULER discarding; MES SETS unfolding on
# the phone.
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
      click_on "Save"
    end

    assert_no_selector "dialog[open]"
    assert_current_path library_path(locale: :en)
    within("section.custom-sets") do
      assert_text "Visible to you only · 1 / 10"
      assert_selector "li:first-child > a.set-tile .set-tile__face--recto .set-tile__head", text: /Mes favoris\s+custom set · 3 games\s+1\/3/i
      assert_selector "li:last-child > button.new-set-tile"
    end
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
      find(".custom-sets__unfold", text: /\Aet 2 autres sets · tout voir\z/i).click
      assert_selector "a.set-tile", count: 4
      assert_no_selector ".custom-sets__unfold"
      assert_selector "ul.custom-sets__tiles > li:nth-child(3) > a.set-tile:focus"
      assert_selector "ul.custom-sets__tiles > li:last-child > button.new-set-tile"
    end
  end
end
