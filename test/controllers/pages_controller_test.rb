require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  test "the root page names gameble and loads its Vite assets" do
    get root_path

    assert_response :success
    assert_select "h1", "gameble"
    assert_select "script[type=module][src^='/vite-test/assets/application-'][src$='.js']"
    assert_select "link[rel=stylesheet][href^='/vite-test/assets/application-'][href$='.css']"
  end

  test "the health check answers when the application boots" do
    get rails_health_check_path

    assert_response :success
  end

  test "an unknown path answers not found" do
    get "/nope"

    assert_response :not_found
  end
end
