require "application_system_test_case"

class SampleIslandTest < ApplicationSystemTestCase
  test "the sample island renders its French strings and its data" do
    visit home_path(locale: :fr)

    within ".sample-island" do
      assert_selector "h2", text: "Le tableau de rassemblement de la Confrérie"
      assert_text "Saison de service en cours : 1"
    end
  end

  test "the sample island renders its English strings and its data" do
    visit home_path(locale: :en)

    within ".sample-island" do
      assert_selector "h2", text: "The Brotherhood muster board"
      assert_text "Current season of service: 1"
    end
  end

  test "a Turbo visit to the attic leaves the island mounted once" do
    visit home_path(locale: :en)
    assert_selector ".sample-island", count: 1

    page.execute_script(<<~JS)
      window.turboVisitMarker = true
      window.turboLoads = 0
      document.addEventListener("turbo:load", () => {
        window.turboLoads += 1
        document.body.dataset.turboLoads = window.turboLoads
      })
    JS
    page.execute_script("Turbo.visit(location.href)")

    assert_selector "body[data-turbo-loads='1']"
    assert_selector ".sample-island", count: 1
    assert page.evaluate_script("window.turboVisitMarker"), "the visit should go through Turbo, not a full page load"
  end
end
