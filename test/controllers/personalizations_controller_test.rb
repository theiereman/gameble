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
    assert_no_match %r{/brothers/}, response.location
  end

  test "the old page leads to the player's own profile, where the editing now lives" do
    sign_in(@player)

    get personalization_path(locale: :fr)

    assert_response :moved_permanently
    assert_redirected_to brother_path(locale: :fr, token: @player.token)
  end

  test "the own profile shows the chosen cards of the showcase in their order, each movable and removable, and no id" do
    common, rare = catalog_card_seasons(:common_card_one, :rare_card_one).map(&:id)
    [ common, rare ].each { Game::Holding.create!(player_id: @player.id, card_season_id: it, quantity: 1) }
    [ rare, common ].each { Game::AddToShowcase.new.call(player: @player, card_season_id: it).value! }
    sign_in(@player)

    get brother_path(locale: :fr, token: @player.token)

    assert_response :success
    assert_select "section.profile-section h2#profile-showcase-heading", "Vitrine"
    assert_equal [ "/fr/cards/blue-depths/seasons/1?brother=#{@player.token}", "/fr/cards/tin-soldier/seasons/1?brother=#{@player.token}" ],
      css_select(".profile-showcase .profile-showcase__slot > a.card-link").map { it["href"] }
    assert_select ".profile-showcase__slot form[data-direction]", 4
    assert_select ".profile-showcase__slot button[aria-label^=?]", "Retirer", 2
    assert_select ".profile-showcase__info-text", /croix/
    assert_select "[style]", false
    [ @player.id, common, rare ].each { assert_no_match(/\b#{it}\b/, css_select("main").to_html.gsub(/data-card-art-(width|height)-value="\d+"|\/seasons\/\d+|\b(19|20)\d\d\b/, "")) }
  end

  test "with no card chosen the own profile says how to choose one, and a visitor sees no showcase at all" do
    sign_in(@player)

    get brother_path(locale: :en, token: @player.token)

    assert_select ".profile-showcase", false
    assert_select ".profile-section__empty", /Your best card/

    sign_in(accounts_players(:moderator))
    get brother_path(locale: :en, token: @player.token)

    assert_select "#profile-showcase-heading", false
  end

  test "the PLUS list no longer leads to a personalization page" do
    sign_in(@player)

    get more_path(locale: :en)

    assert_select ".plus__list a[href=?]", personalization_path(locale: :en), false
  end
end
