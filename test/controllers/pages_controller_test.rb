require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  OBJECT_NAMES = {
    fr: [ "Bibliothèque", "Le fil de la Confrérie", "Succès", "Mon profil", "Échanges et amis", "Le coffre" ],
    en: [ "Library", "Brotherhood feed", "Achievements", "My profile", "Trades and friends", "The chest" ]
  }.freeze

  setup do
    OmniAuth.config.test_mode = true
  end

  teardown do
    OmniAuth.config.mock_auth.delete(:steam)
    OmniAuth.config.test_mode = false
  end

  def sign_in(player, origin: "/en")
    OmniAuth.config.mock_auth[:steam] = OmniAuth::AuthHash.new(provider: "steam", uid: "https://steamcommunity.com/openid/id/#{player.steam_id}")
    post "/auth/steam", params: { origin: origin }
    follow_redirect!
    assert_equal player.id, session[:player_id]
  end

  def assert_attic_room(locale)
    assert_select ".attic[data-controller=attic] .attic__room"
    assert_select ".attic__window"
    assert_select ".attic__object", 6
    assert_equal OBJECT_NAMES.fetch(locale), css_select(".attic__object .attic__name").map(&:text)
    assert_select ".attic__object--chest[data-attic-target=chest]"
    # Only the lectern holds a link, its art and name, to the library; the
    # chest's one button opens a pack; no other object acts.
    lectern = css_select(".attic__object--lectern a").sole
    assert_equal "/#{locale}/library", lectern["href"]
    assert_equal [ "attic__link" ], lectern.classes
    assert_equal "false", lectern["data-turbo-prefetch"]
    assert_equal OBJECT_NAMES.fetch(locale).first, lectern.at_css(".attic__name").text
    assert lectern.at_css(".attic__art[aria-hidden=true]")
    assert_select ".attic__object a", 1
    assert_select ".attic__object:not(.attic__object--chest) button", false
    assert_select ".attic__object--chest .attic__chest-action button", 1
  end

  test "the French shell renders in French with the top bar above the main region" do
    get home_path(locale: :fr)

    assert_response :success
    assert_select "html[lang=fr]"
    assert_select "title", "gameble"
    assert_select "h1", "Le grenier de la Confrérie"
    assert_select "body > header.top-bar + main#main"
    assert_select "nav.tab-bar[aria-label=?]", "Navigation principale"
  end

  test "the English shell renders in English and loads its Vite assets" do
    get home_path(locale: :en)

    assert_response :success
    assert_select "html[lang=en]"
    assert_select "title", "gameble"
    assert_select "h1", "The attic of the Brotherhood"
    assert_select "body > header.top-bar + main#main"
    assert_select "script[type=module][src^='/vite-test/assets/application-'][src$='.js']"
    assert_select "link[rel=stylesheet][href^='/vite-test/assets/application-'][href$='.css']"
  end

  test "a visitor sees the attic, the sign-in invitation and the sign-in button, and no back-office link" do
    get home_path(locale: :fr)

    assert_response :success
    assert_attic_room(:fr)
    assert_select ".attic__invitation", "Enrôle-toi via Steam, Confrère, et le coffre s'ouvrira pour toi."
    assert_select ".top-bar__end form.steam-sign-in[action='/auth/steam'] input[name=origin][value='/fr']"
    assert_select "a[href='/fr/back-office']", false
    assert_select ".top-bar__start a.button", false
  end

  test "a player sees the attic without the invitation, with the sign-out button and no back-office link" do
    sign_in(accounts_players(:player))

    get home_path(locale: :en)

    assert_response :success
    assert_attic_room(:en)
    assert_select ".attic__invitation", false
    assert_select "#player-menu form[action^='/session']"
    assert_select ".top-bar form[action='/auth/steam']", false
    assert_select "a[href='/en/back-office']", false
  end

  test "a sign-in started on the attic lands on the attic" do
    sign_in(accounts_players(:player), origin: "/fr")

    assert_redirected_to "/fr"
    follow_redirect!
    assert_response :success
    assert_select "h1", "Le grenier de la Confrérie"
    assert_attic_room(:fr)
  end

  [ :moderator, :administrator ].each do |role|
    test "a #{role} sees the back-office link in the player menu, in the current locale" do
      sign_in(accounts_players(role))

      get home_path(locale: :fr)

      assert_select "#player-menu a.player-menu__item[href='/fr/back-office']", "Back-office"
    end
  end

  test "the sample island's mount element carries its name and French props from the server" do
    get home_path(locale: :fr)

    assert_select ".attic__plaque [data-controller=turbo-mount-sample-island]" do |elements|
      element = elements.sole
      assert_equal "SampleIsland", element["data-turbo-mount-sample-island-component-value"]
      assert_equal(
        {
          "data" => { "season" => 1 },
          "strings" => {
            "heading" => "Le tableau de rassemblement de la Confrérie",
            "season" => "Saison de service en cours :"
          }
        },
        JSON.parse(element["data-turbo-mount-sample-island-props-value"])
      )
    end
  end

  test "an unknown locale segment answers not found" do
    get "/de"

    assert_response :not_found
  end

  test "the health check answers when the application boots" do
    get "/up"

    assert_response :success
  end

  test "an unknown path answers not found" do
    get "/nope"

    assert_response :not_found
  end
end
