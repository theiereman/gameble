require "test_helper"
require_relative "../support/steam_sign_in"

# The Content-Security-Policy (config/initializers/content_security_policy.rb):
# enforced, styles nonced, scripts nonced only for Mission Control Jobs (other
# pages keep script-src 'self', Clerk's bot protection and Cloudflare's
# analytics beacon), Steam's image hosts, the cable's ws(s) origin and Clerk
# allowed.
class ContentSecurityPolicyTest < ActionDispatch::IntegrationTest
  include SteamSignIn

  CLERK_BOT_PROTECTION = %w[https://challenges.cloudflare.com https://cdn.protect.clerk.com].freeze
  THIRD_PARTY_SCRIPTS = [ *CLERK_BOT_PROTECTION, "https://*.client.protect.clerk.com", "https://static.cloudflareinsights.com" ].freeze

  setup { @public_url = Rails.configuration.x.public_url }
  teardown { Rails.configuration.x.public_url = @public_url }

  def policy
    response.headers["Content-Security-Policy"]
  end

  def directive(name)
    policy.split(/;\s*/).find { |entry| entry.split.first == name }&.split&.drop(1)
  end

  def third_party_connections
    [ "https://#{Rails.configuration.x.clerk.frontend_api}", *CLERK_BOT_PROTECTION, "https://*.client.protect.clerk.com:*", "https://cloudflareinsights.com" ]
  end

  test "a page carries the policy enforced, never report-only" do
    get how_it_works_path(locale: :en)

    assert_response :success
    assert_predicate policy, :present?
    assert_nil response.headers["Content-Security-Policy-Report-Only"]
  end

  test "a player's page runs scripts from its own origin only, without a nonce" do
    sign_in(accounts_players(:player))
    get library_path(locale: :en)

    assert_response :success
    assert_equal [ "'self'", *THIRD_PARTY_SCRIPTS ], directive("script-src")
  end

  test "the directives: self by default, no inline script, nonced styles, Steam images, workers from blobs, Clerk" do
    Rails.configuration.x.public_url = nil
    get home_path(locale: :en)

    assert_equal %w['self'], directive("default-src")
    assert_equal %w['self'], directive("base-uri")
    assert_equal %w['none'], directive("object-src")
    assert_equal [ "'self'", *THIRD_PARTY_SCRIPTS ], directive("script-src")
    assert_equal [ "'self'", *CLERK_BOT_PROTECTION ], directive("frame-src")
    assert_equal "'self'", directive("style-src").first
    assert_match(/\A'nonce-.+'\z/, directive("style-src").second)
    assert_equal 2, directive("style-src").size
    assert_equal %w['self' data: https://*.steamstatic.com], directive("img-src")
    assert_equal %w['self' data:], directive("font-src")
    assert_equal %w['self' blob:], directive("worker-src")
    assert_equal [ "'self'", "https://*.steamstatic.com", *third_party_connections ], directive("connect-src")
    assert_nil directive("report-uri")
  end

  test "the style nonce is the one the page's meta tag gives Turbo" do
    get how_it_works_path(locale: :en)

    nonce = directive("style-src").second[/\A'nonce-(.+)'\z/, 1]
    assert_equal nonce, css_select("meta[name=csp-nonce]").sole["content"]
  end

  test "within a session the nonce stays the same from page to page, as Turbo visits need" do
    sign_in(accounts_players(:player))

    get home_path(locale: :en)
    first = directive("style-src").second
    get library_path(locale: :en)

    assert_equal first, directive("style-src").second
  end

  test "connect-src allows the cable's origin from the public URL, wss for https and ws for http" do
    Rails.configuration.x.public_url = "https://gameble.example"
    get home_path(locale: :en)
    assert_equal [ "'self'", "https://*.steamstatic.com", "wss://gameble.example", *third_party_connections ], directive("connect-src")

    Rails.configuration.x.public_url = "http://gameble.test:8080"
    get home_path(locale: :en)
    assert_equal [ "'self'", "https://*.steamstatic.com", "ws://gameble.test:8080", *third_party_connections ], directive("connect-src")
  end
end
