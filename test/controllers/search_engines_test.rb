require "test_helper"
require_relative "../support/catalog_seeds"

class SearchEnginesTest < ActionDispatch::IntegrationTest
  include CatalogSeeds

  BASE = "https://gameble.example"

  setup do
    @public_url = Rails.configuration.x.public_url
    @search_indexing = Rails.configuration.x.search_indexing
    Rails.configuration.x.public_url = BASE
    Rails.configuration.x.search_indexing = true
  end

  teardown do
    Rails.configuration.x.public_url = @public_url
    Rails.configuration.x.search_indexing = @search_indexing
  end

  test "the landing has its own title and description in each language" do
    get home_path(locale: :en)
    assert_select "title", I18n.t("landings.show.title", locale: :en)
    assert_select "meta[name=description][content=?]", I18n.t("landings.show.description", locale: :en)

    get home_path(locale: :fr)
    assert_select "title", I18n.t("landings.show.title", locale: :fr)
    assert_select "meta[name=description][content=?]", I18n.t("landings.show.description", locale: :fr)
    assert_not_equal I18n.t("landings.show.title", locale: :en), I18n.t("landings.show.title", locale: :fr)
  end

  test "the landing links its canonical address and its language alternates on the public base" do
    get home_path(locale: :fr)

    assert_select "link[rel=canonical][href=?]", "#{BASE}/fr"
    assert_select "link[rel=alternate][hreflang=fr][href=?]", "#{BASE}/fr"
    assert_select "link[rel=alternate][hreflang=en][href=?]", "#{BASE}/en"
    assert_select "link[rel=alternate][hreflang=x-default][href=?]", "#{BASE}/"
    assert_select "meta[property='og:url'][content=?]", "#{BASE}/fr"
    assert_select "meta[property='og:locale'][content=fr_FR]"
    assert_select "meta[property='og:locale:alternate'][content=en_US]"
    assert_select "meta[name=robots]", false
  end

  test "the landing carries valid structured data for the game, outside the script policy" do
    get home_path(locale: :en)

    block = css_select("script[type='application/ld+json']").sole
    data = JSON.parse(block.text)
    assert_equal "https://schema.org", data["@context"]
    game = data["@graph"].find { it["@type"] == "VideoGame" }
    assert_equal "#{BASE}/en", game["url"]
    assert_equal I18n.t("landings.show.description", locale: :en), game["description"]
    assert_equal true, game["isAccessibleForFree"]
    assert_nil block["nonce"]
  end

  test "the legal page links its canonical address and its alternates" do
    get legal_path(locale: :en)

    assert_select "link[rel=canonical][href=?]", "#{BASE}/en/legal"
    assert_select "link[rel=alternate][hreflang=fr][href=?]", "#{BASE}/fr/legal"
  end

  test "the sitemap lists the landing and the legal page in both languages, with their alternates, and no private page" do
    get "/sitemap.xml"

    assert_response :success
    assert_equal "application/xml", response.media_type
    document = Nokogiri::XML(response.body)
    document.remove_namespaces!
    assert_equal %W[#{BASE}/en #{BASE}/fr #{BASE}/en/legal #{BASE}/fr/legal].sort, document.xpath("//url/loc").map(&:text).sort
    first = document.at_xpath("//url[loc='#{BASE}/fr']")
    assert_equal %w[en fr], first.xpath("link[@rel='alternate']/@hreflang").map(&:value).sort
    assert_no_match(/back-office|settings|booster|trades|brothers|cards/, response.body)
  end

  test "robots.txt points to the sitemap and disallows the back-office and private screens" do
    get "/robots.txt"

    assert_response :success
    assert_nil response.headers["Set-Cookie"]
    assert_equal "text/plain", response.media_type
    lines = response.body.lines.map(&:chomp)
    assert_includes lines, "Sitemap: #{BASE}/sitemap.xml"
    [ "/back-office", "/auth/", "/*/back-office", "/*/settings", "/*/booster", "/*/trades", "/*/friends" ].each do |path|
      assert_includes lines, "Disallow: #{path}"
    end
    %w[cards brothers library roadmap legal feed].each do |page|
      assert_not_includes lines, "Disallow: /*/#{page}"
    end
    assert_not_includes lines, "Disallow: /"
  end

  test "the crawler files are open to a visitor on any browser" do
    get "/robots.txt", headers: { "User-Agent" => "Googlebot/2.1" }
    assert_response :success
    get "/sitemap.xml", headers: { "User-Agent" => "Googlebot/2.1" }
    assert_response :success
  end

  test "indexing on: no page asks search engines to stay out" do
    get home_path(locale: :en)

    assert_nil response.headers["X-Robots-Tag"]
  end

  test "indexing on: a public profile, its collection and an album still ask search engines to stay out, and robots.txt lets them read the tag" do
    owner = accounts_players(:player)

    get brother_path(locale: :en, token: owner.token)
    assert_select "meta[name=robots][content=noindex]"

    get brother_collection_path(locale: :en, token: owner.token)
    assert_select "meta[name=robots][content=noindex]"

    get "/robots.txt"
    assert_not_includes response.body.lines.map(&:chomp), "Disallow: /*/brothers"
  end

  test "indexing off: robots.txt refuses everything and names no sitemap, the sitemap is not found" do
    Rails.configuration.x.search_indexing = false

    get "/robots.txt"
    assert_equal "User-agent: *\nDisallow: /\n", response.body

    get "/sitemap.xml"
    assert_response :not_found
  end

  test "indexing off: every page says noindex, and the landing and legal page drop their search tags" do
    Rails.configuration.x.search_indexing = false

    [ home_path(locale: :fr), legal_path(locale: :fr), "/robots.txt" ].each do |path|
      get path
      assert_equal "noindex, nofollow", response.headers["X-Robots-Tag"], path
    end
    get home_path(locale: :fr)
    assert_select "link[rel=canonical], link[rel=alternate], meta[property^='og:'], meta[name=description], script[type='application/ld+json']", 0
    get legal_path(locale: :fr)
    assert_select "link[rel=canonical], link[rel=alternate]", 0
  end
end
