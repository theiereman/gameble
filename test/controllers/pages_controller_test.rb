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
    assert_select ".attic__object a, .attic__object button", false
  end

  test "the French shell renders in French with the status band above the main region" do
    get home_path(locale: :fr)

    assert_response :success
    assert_select "html[lang=fr]"
    assert_select "title", "gameble · La Grande Confrérie des Gamblers"
    assert_select "h1", "Le grenier de la Confrérie"
    assert_select "body > header.status-band + main"
    assert_select "header.status-band[aria-label=?]", "État de la Confrérie"
    assert_select "section[aria-label=?]", "Objectif de la semaine"
    assert_select "section[aria-label=?]", "Paquets et cartes"
  end

  test "the English shell renders in English and loads its Vite assets" do
    get home_path(locale: :en)

    assert_response :success
    assert_select "html[lang=en]"
    assert_select "title", "gameble · The Grand Gamblers' Brotherhood"
    assert_select "h1", "The attic of the Brotherhood"
    assert_select "body > header.status-band + main"
    assert_select "script[type=module][src^='/vite-test/assets/application-'][src$='.js']"
    assert_select "link[rel=stylesheet][href^='/vite-test/assets/application-'][href$='.css']"
  end

  test "a visitor sees the attic, the sign-in invitation and the sign-in button, and no back-office link" do
    get home_path(locale: :fr)

    assert_response :success
    assert_attic_room(:fr)
    assert_select ".attic__invitation", "Enrôle-toi via Steam, Confrère, et le coffre s'ouvrira pour toi."
    assert_select ".status-band__counters form[action='/auth/steam'] input[name=origin][value='/fr']"
    assert_select "a[href='/fr/back-office']", false
    assert_select ".status-band > a.button", false
  end

  test "a player sees the attic without the invitation, with the sign-out button and no back-office link" do
    sign_in(accounts_players(:player))

    get home_path(locale: :en)

    assert_response :success
    assert_attic_room(:en)
    assert_select ".attic__invitation", false
    assert_select ".status-band__counters form[action^='/session']"
    assert_select ".status-band__counters form[action='/auth/steam']", false
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
    test "a #{role} sees the back-office link in the status band, in the current locale" do
      sign_in(accounts_players(role))

      get home_path(locale: :fr)

      assert_select ".status-band__counters a.button--secondary[href='/fr/back-office']", "Back-office"
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
