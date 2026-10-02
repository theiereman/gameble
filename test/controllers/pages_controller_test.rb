require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  test "the French shell renders in French with the status band above the main region" do
    get home_path(locale: :fr)

    assert_response :success
    assert_select "html[lang=fr]"
    assert_select "title", "gameble · La Grande Confrérie des Gamblers"
    assert_select "h1", "Bienvenue aux archives, Confrère"
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
    assert_select "h1", "Welcome to the archives, Brother"
    assert_select "body > header.status-band + main"
    assert_select "script[type=module][src^='/vite-test/assets/application-'][src$='.js']"
    assert_select "link[rel=stylesheet][href^='/vite-test/assets/application-'][href$='.css']"
  end

  test "links built with route helpers keep the current locale" do
    get home_path(locale: :fr)

    assert_select "a.button--primary[href='/fr']"
    assert_select "a.button--secondary[href='/fr']"
  end

  test "the sample island's mount element carries its name and French props from the server" do
    get home_path(locale: :fr)

    assert_select "[data-controller=turbo-mount-sample-island]" do |elements|
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
