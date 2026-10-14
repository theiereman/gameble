require "test_helper"

# The static error pages in public/ hold no inline style, which the
# enforced Content-Security-Policy would block: they share /errors.css.
class ErrorPagesTest < ActionDispatch::IntegrationTest
  OLD_BROWSER = "Mozilla/5.0 (Windows NT 6.1; Trident/7.0; rv:11.0) like Gecko"

  def self.error_pages = Rails.public_path.glob("*.html")

  test "the error pages are 400, 404, 406, 422 and 500" do
    assert_equal %w[400.html 404.html 406-unsupported-browser.html 422.html 500.html], self.class.error_pages.map { it.basename.to_s }.sort
  end

  error_pages.each do |page|
    test "#{page.basename} links /errors.css and holds no inline style" do
      html = Nokogiri::HTML(page.read)

      assert_empty html.css("style")
      assert_empty html.css("[style]")
      assert_equal [ "/errors.css" ], html.css("link[rel=stylesheet]").map { it["href"] }
    end
  end

  test "the stylesheet is served from public/" do
    get "/errors.css"

    assert_response :success
    assert_equal "text/css", response.media_type
  end

  test "an unknown address gets the 404 page, styled by /errors.css" do
    env_config = Rails.application.env_config
    detailed = env_config["action_dispatch.show_detailed_exceptions"]
    env_config["action_dispatch.show_detailed_exceptions"] = false
    begin
      get "/en/no-such-page"
    ensure
      env_config["action_dispatch.show_detailed_exceptions"] = detailed
    end

    assert_response :not_found
    assert_nil response.headers["Content-Security-Policy"]
    assert_select "link[rel=stylesheet][href='/errors.css']"
    assert_select "style", false
  end

  test "an old browser on a page not meant to be shared gets the 406 page under the enforced policy" do
    get home_path(locale: :en), headers: { "User-Agent" => OLD_BROWSER }

    assert_response :not_acceptable
    assert_predicate response.headers["Content-Security-Policy"], :present?
    assert_nil response.headers["Content-Security-Policy-Report-Only"]
    assert_select "link[rel=stylesheet][href='/errors.css']"
    assert_select "style", false
    assert_select "[style]", false
  end
end
