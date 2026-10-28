require "test_helper"
require_relative "../support/steam_sign_in"

class PersonalizationsControllerTest < ActionDispatch::IntegrationTest
  include SteamSignIn

  setup do
    @player = accounts_players(:player)
  end

  test "a visitor is sent to sign in" do
    get personalization_path(locale: :en)

    assert_response :redirect
  end

  test "the page shows the chosen cards of the showcase in their order, linking to their details, and no id" do
    common, rare = catalog_card_seasons(:common_card_one, :rare_card_one).map(&:id)
    [ common, rare ].each { Game::Holding.create!(player_id: @player.id, card_season_id: it, quantity: 1) }
    [ rare, common ].each { Game::AddToShowcase.new.call(player: @player, card_season_id: it).value! }
    sign_in(@player)

    get personalization_path(locale: :fr)

    assert_response :success
    assert_select "h1#personalization-heading", "Personnalisation"
    assert_select "section.personalization-section h2#profile-showcase-heading", "Vitrine"
    assert_equal [ "/fr/cards/blue-depths/seasons/1?from=personalization", "/fr/cards/tin-soldier/seasons/1?from=personalization" ],
      css_select(".profile-showcase .profile-showcase__slot > a.card-link").map { it["href"] }
    assert_select ".profile-showcase__slot form[data-direction]", 4
    assert_select ".profile-showcase__slot button[aria-label^=?]", "Retirer", 2
    assert_select ".card.card--grid", 2
    assert_select ".profile-showcase__info-text", /croix/
    assert_select "[style]", false
    [ @player.id, common, rare ].each { assert_no_match(/\b#{it}\b/, css_select("main").to_html.gsub(/data-card-art-(width|height)-value="\d+"|\/seasons\/\d+|\b(19|20)\d\d\b/, "")) }
  end

  test "with no card chosen the section says how to choose one" do
    sign_in(@player)

    get personalization_path(locale: :en)

    assert_select ".profile-showcase", false
    assert_select ".personalization-section__empty", /Your best card/
  end

  test "the player menu and the PLUS list lead to the page, and the settings no longer show the showcase" do
    sign_in(@player)

    get settings_path(locale: :en)

    assert_select "nav#player-menu a[href=?]", personalization_path(locale: :en), "Personalization"
    assert_select ".settings-summary .profile-showcase, .settings-summary__showcase", false

    get more_path(locale: :en)

    assert_select ".plus__list a[href=?]", personalization_path(locale: :en), /Personalization/
  end
end
