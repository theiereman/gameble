require "test_helper"

# The Content-Security-Policy (AD-27, config/initializers/content_security_policy.rb):
# report-only for now, no inline script, nonces on styles only, Steam's
# image hosts and the cable's ws(s) origin allowed.
class ContentSecurityPolicyTest < ActionDispatch::IntegrationTest
  setup { @public_url = Rails.configuration.x.public_url }
  teardown { Rails.configuration.x.public_url = @public_url }

  def policy
    response.headers["Content-Security-Policy-Report-Only"]
  end

  def directive(name)
    policy.split(/;\s*/).find { |entry| entry.split.first == name }&.split&.drop(1)
  end

  test "a page carries the policy report-only, never enforced" do
    get home_path(locale: :en)

    assert_response :success
    assert_predicate policy, :present?
    assert_nil response.headers["Content-Security-Policy"]
  end

  test "the directives: self by default, no inline script, nonced styles, Steam images, workers from blobs" do
    Rails.configuration.x.public_url = nil
    get home_path(locale: :en)

    assert_equal %w['self'], directive("default-src")
    assert_equal %w['self'], directive("base-uri")
    assert_equal %w['none'], directive("object-src")
    assert_equal %w['self'], directive("script-src")
    assert_equal "'self'", directive("style-src").first
    assert_match(/\A'nonce-.+'\z/, directive("style-src").second)
    assert_equal 2, directive("style-src").size
    assert_equal %w['self' data: https://*.steamstatic.com], directive("img-src")
    assert_equal %w['self'], directive("font-src")
    assert_equal %w['self' blob:], directive("worker-src")
    assert_equal %w['self' https://*.steamstatic.com], directive("connect-src")
    assert_nil directive("report-uri")
  end

  test "the style nonce is the one the page's meta tag gives Turbo" do
    get home_path(locale: :en)

    nonce = directive("style-src").second[/\A'nonce-(.+)'\z/, 1]
    assert_equal nonce, css_select("meta[name=csp-nonce]").sole["content"]
  end

  test "within a session the nonce stays the same from page to page, as Turbo visits need" do
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:steam] = OmniAuth::AuthHash.new(provider: "steam",
      uid: "https://steamcommunity.com/openid/id/#{accounts_players(:player).steam_id}")
    post "/auth/steam", params: { origin: "/en" }
    follow_redirect!

    get home_path(locale: :en)
    first = directive("style-src").second
    get library_path(locale: :en)

    assert_equal first, directive("style-src").second
  ensure
    OmniAuth.config.mock_auth.delete(:steam)
    OmniAuth.config.test_mode = false
  end

  test "connect-src allows the cable's origin from the public URL, wss for https and ws for http" do
    Rails.configuration.x.public_url = "https://gameble.example"
    get home_path(locale: :en)
    assert_equal %w['self' https://*.steamstatic.com wss://gameble.example], directive("connect-src")

    Rails.configuration.x.public_url = "http://gameble.test:8080"
    get home_path(locale: :en)
    assert_equal %w['self' https://*.steamstatic.com ws://gameble.test:8080], directive("connect-src")
  end
end
