require "test_helper"
require_relative "../support/market"
require_relative "../support/roadmap_seeds"
require_relative "../support/steam_sign_in"

# A client that asks for text/markdown reads the public pages as markdown;
# every other request keeps HTML, and nothing player-specific turns markdown.
class MarkdownNegotiationTest < ActionDispatch::IntegrationTest
  include MarketSettings
  include RoadmapSeeds
  include SteamSignIn

  MARKDOWN = { "Accept" => "text/markdown" }.freeze
  BROWSER_ACCEPT = "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8"

  setup { Rails.cache.clear }
  teardown { Rails.cache.clear }

  def public_paths(locale = :en)
    [ home_path(locale:), roadmap_path(locale:), legal_path(locale:), how_it_works_path(locale:), credits_path(locale:) ]
  end

  def assert_markdown
    assert_response :success
    assert_equal "text/markdown; charset=utf-8", response.headers["Content-Type"]
    assert_includes response.headers["Vary"].split(/,\s*/), "Accept"
    assert_no_match(/<(?:div|section|article|p|h\d|ul|li|a|span)[\s>]/, response.body)
  end

  test "a visitor reads every public page as markdown" do
    public_paths.each do |path|
      get path, headers: MARKDOWN

      assert_markdown
      assert_match(/^# \S/, response.body, path)
    end
  end

  test "the landing in markdown carries the hook, the steps and the links in the locale" do
    get home_path(locale: :fr), headers: MARKDOWN

    assert_markdown
    assert_includes response.body, "# #{I18n.t("landings.show.hero.hook", locale: :fr)}"
    assert_includes response.body, "1. **#{I18n.t("landings.show.how.join.title", locale: :fr)}**"
    assert_includes response.body, "](http://www.example.com/fr/legal)"
  end

  test "the roadmap in markdown lists the shown milestones and stories and nothing hidden" do
    seed_roadmap_with_hidden_story

    get roadmap_path(locale: :en), headers: MARKDOWN

    assert_markdown
    assert_includes response.body, "Step alpha"
    assert_includes response.body, "Story a"
    assert_not_includes response.body, "Story hidden"
  end

  test "the legal page in markdown names the publisher contact" do
    configured = Rails.configuration.x.legal
    Rails.configuration.x.legal = ActiveSupport::OrderedOptions.new.update(contact_email: "contact@example.test", host_name: "Example Hosting", host_address: "France")

    get legal_path(locale: :en), headers: MARKDOWN

    assert_markdown
    assert_includes response.body, "contact@example.test"
    assert_includes response.body, "Example Hosting"
  ensure
    Rails.configuration.x.legal = configured
  end

  test "the how-it-works page in markdown keeps its odds tables" do
    get how_it_works_path(locale: :en), headers: MARKDOWN

    assert_markdown
    assert_match(/^\| .+ \|$/, response.body)
    assert_match(/^\| --- \| --- \|$/, response.body)
  end

  test "the how-it-works page in markdown carries the market section only after the first opening" do
    Game::Market::Settings.delete_all
    open_market!(open: false, first_opened_at: nil)

    get how_it_works_path(locale: :en), headers: MARKDOWN

    assert_no_match(/The market/, response.body)

    open_market!(first_opened_at: Time.current)
    get how_it_works_path(locale: :en), headers: MARKDOWN

    assert_markdown
    assert_match(/^#+ The market$/, response.body)
  end

  test "no database id appears in the markdown" do
    seed_roadmap_with_hidden_story

    public_paths.each do |path|
      get path, headers: MARKDOWN

      urls = response.body.scan(%r{\]\((\S+?)\)}).flatten

      assert urls.none? { |url| url.match?(%r{/\d+(?:[/?#]|\z)}) }, "#{path} #{urls}"
    end
  end

  test "q-values choose the representation" do
    {
      "text/markdown, text/html;q=0.8" => :markdown,
      "text/markdown;q=0.9, */*;q=0.1" => :markdown,
      "text/markdown, */*" => :markdown,
      "TEXT/MARKDOWN;q=1.0,text/html;q=0.5" => :markdown,
      "text/html, text/markdown;q=0.5" => :html,
      "text/markdown;q=0.5, */*;q=0.8" => :html,
      "text/markdown, text/html" => :html
    }.each do |accept, expected|
      get roadmap_path(locale: :en), headers: { "Accept" => accept }

      assert_response :success, accept
      assert_equal expected == :markdown ? "text/markdown" : "text/html", response.media_type, accept
    end
  end

  test "HTML stays the default for browsers, */* and a missing Accept" do
    [ BROWSER_ACCEPT, "*/*", "text/html", nil ].each do |accept|
      public_paths.each do |path|
        get path, headers: ({ "Accept" => accept } if accept)

        assert_response :success, "#{path} #{accept.inspect}"
        assert_equal "text/html", response.media_type, "#{path} #{accept.inspect}"
      end
    end
  end

  test "both representations vary on Accept" do
    public_paths.each do |path|
      [ MARKDOWN, { "Accept" => "text/html" } ].each do |headers|
        get path, headers: headers

        assert_includes response.headers["Vary"].to_s.split(/,\s*/), "Accept", "#{path} #{headers}"
      end
    end
  end

  test "the root redirects a markdown request to the locale like an HTML one" do
    get "/", headers: MARKDOWN.merge("Accept-Language" => "fr")

    assert_redirected_to "/fr"
  end

  test "a signed-in player's markdown request does not get the hub as markdown" do
    sign_in(accounts_players(:player))

    get home_path(locale: :en), headers: MARKDOWN

    assert_not_equal "text/markdown", response.media_type
    assert_not_equal "200", response.code
  end

  test "private pages ask for a sign-in whatever the visitor accepts" do
    get settings_path(locale: :en), headers: MARKDOWN

    assert_response :unauthorized
    assert_empty response.body
  end

  test "a private page in HTML is unchanged for a signed-in player" do
    sign_in(accounts_players(:player))

    get settings_path(locale: :en), headers: { "Accept" => BROWSER_ACCEPT }

    assert_response :success
    assert_equal "text/html", response.media_type
  end

  private
    def seed_roadmap_with_hidden_story
      seed_roadmap(stories: [ [ "a", "done", true ], [ "hidden", "done", false ] ])
    end
end
