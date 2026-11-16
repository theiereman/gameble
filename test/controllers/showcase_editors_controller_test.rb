require "test_helper"
require_relative "../support/catalog_seeds"
require_relative "../support/game_sets"
require_relative "../support/holdings"
require_relative "../support/steam_sign_in"

class ShowcaseEditorsControllerTest < ActionDispatch::IntegrationTest
  include CatalogSeeds
  include GameSets
  include Holdings
  include SteamSignIn

  setup do
    @player = accounts_players(:player)
  end

  def choose(*ids) = ids.each { Game::AddToShowcase.new.call(player: @player, card_season_id: it).value! }

  def title(id, locale: :en) = Catalog::CardViews.call([ id ], locale:)[id].title

  def toggle(slug) = css_select(".showcase-pick form[action$='/cards/#{slug}/seasons/1/showcase']").sole

  test "the editor lists the cards held, each a toggle pressed once chosen, over a dock counting the chosen ones, and the GET writes nothing" do
    portal, tin_soldier = catalog_card_seasons(:portal_one, :common_card_one).map(&:id)
    [ portal, tin_soldier ].each { hold(@player, it) }
    choose(portal)
    sign_in(@player)

    assert_no_difference -> { Game::ShowcaseEntry.count } do
      get edit_showcase_path(locale: :en)
    end

    assert_response :success
    assert_select "title", /Edit the showcase/
    assert_select "meta[name=turbo-refresh-method][content=morph]"
    assert_select "section.showcase-editor[data-layout=wide] h1.visually-hidden", "Edit the showcase"
    assert_select ".showcase-pick", 2
    assert_select toggle("portal"), "input[name=_method][value=delete]"
    assert_select toggle("portal"), "button.showcase-pick__toggle[aria-pressed=true][aria-label=?]:not([disabled])", title(portal)
    assert_select toggle("tin-soldier"), "input[name=_method]", false
    assert_select toggle("tin-soldier"), "button.showcase-pick__toggle[aria-pressed=false]:not([disabled])"
    assert_select ".showcase-pick--chosen", 1

    assert_select "aside.showcase-dock.dock[aria-labelledby=showcase-dock-heading]" do
      assert_select "h2#showcase-dock-heading", "Your showcase"
      assert_select ".showcase-dock__count[role=status]", "1/5"
      assert_select ".showcase-dock__pick form[action='/en/cards/portal/seasons/1/showcase'] input[name=_method][value=delete]"
      assert_select ".showcase-dock__pick button.showcase-dock__remove[aria-label=?]", "Remove #{title(portal)} from the showcase"
      assert_select ".showcase-dock__free[aria-hidden=true]", 4
      assert_select "a.button[href='/en/me']", "Done"
    end
  end

  test "a card added or taken out from the editor leads back to it" do
    portal = catalog_card_seasons(:portal_one).id
    hold(@player, portal)
    sign_in(@player)
    editor = edit_showcase_path(locale: :en, q: "portal")

    post card_showcase_path(locale: :en, slug: "portal", number: 1), headers: { "HTTP_REFERER" => editor }
    assert_redirected_to editor

    delete card_showcase_path(locale: :en, slug: "portal", number: 1), headers: { "HTTP_REFERER" => editor }
    assert_redirected_to editor
    assert_nil flash[:toast_title]
    assert_empty Game::ChosenShowcase.call(@player)
  end

  test "with five cards chosen the others cannot be added, the chosen ones can still be taken out" do
    _season, ids = published_cards(6)
    ids.each { hold(@player, it) }
    choose(*ids.first(5))
    sign_in(@player)

    get edit_showcase_path(locale: :en)

    assert_select ".showcase-pick", 6
    assert_select ".showcase-pick--chosen button.showcase-pick__toggle:not([disabled])", 5
    assert_select ".showcase-pick:not(.showcase-pick--chosen) button.showcase-pick__toggle[disabled]", 1
    assert_select ".showcase-dock__count", "5/5"
    assert_select ".showcase-dock__free", false
  end

  test "in French: the title, the dock and the removal labels" do
    portal = catalog_card_seasons(:portal_one).id
    hold(@player, portal)
    choose(portal)
    sign_in(@player)

    get edit_showcase_path(locale: :fr)

    assert_select "h1.visually-hidden", "Modifier la vitrine"
    assert_select "h2#showcase-dock-heading", "Votre vitrine"
    assert_select ".showcase-dock__count", "1/5"
    assert_select ".showcase-dock__remove[aria-label=?]", "Retirer #{title(portal, locale: :fr)} de la vitrine"
    assert_select "a.button[href='/fr/me']", "Terminé"
  end

  test "a visitor is sent to the landing" do
    get edit_showcase_path(locale: :fr)

    assert_redirected_to home_path(locale: :fr)
  end
end
