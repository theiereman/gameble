require "test_helper"

class LocalesControllerTest < ActionDispatch::IntegrationTest
  test "a French browser goes to the French pages" do
    get "/", headers: { "Accept-Language" => "fr-FR,fr;q=0.9,en;q=0.8" }

    assert_redirected_to "/fr"
  end

  test "a browser preferring English goes to the English pages" do
    get "/", headers: { "Accept-Language" => "en-US,en;q=0.9,fr;q=0.5" }

    assert_redirected_to "/en"
  end

  test "a regional French variant goes to the French pages" do
    get "/", headers: { "Accept-Language" => "fr-CA" }

    assert_redirected_to "/fr"
  end

  test "an unsupported language falls back to English" do
    get "/", headers: { "Accept-Language" => "de-DE" }

    assert_redirected_to "/en"
  end

  test "no language header falls back to English" do
    get "/"

    assert_redirected_to "/en"
  end

  test "an invalid locale query parameter still redirects" do
    get "/", params: { locale: "de" }
    assert_redirected_to "/en"

    get "/?locale[]=fr"
    assert_redirected_to "/en"
  end
end
