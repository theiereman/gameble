require "test_helper"
require_relative "../support/catalog_seeds"
require_relative "../support/library_requests"

# A card's page as a share link opens it (CAP-9, story 4.5, reworked by the
# epic 4 retrospective fixes): only the card, never who shared or holds it;
# the preview tags (title and rarity, never an image) in the URL's
# language, on the configured public base; for a visitor, the invitation
# to play; open to link-preview crawlers and older browsers, with the
# library its sets lead to; the share links of story 4.5 redirected; no
# database id.
class CardPreviewTagsTest < ActionDispatch::IntegrationTest
  include CatalogSeeds
  include LibraryRequests

  # Discordbot, the old Firefox Discord also fetches with, Twitterbot,
  # WhatsApp and an iOS 16 Safari.
  USER_AGENTS = {
    discordbot: "Mozilla/5.0 (compatible; Discordbot/2.0; +https://discordapp.com)",
    discord_firefox: "Mozilla/5.0 (Macintosh; Intel Mac OS X 11.6; rv:92.0) Gecko/20100101 Firefox/92.0",
    twitterbot: "Twitterbot/1.0",
    whatsapp: "WhatsApp/2.23.20.0 A",
    ios_16_safari: "Mozilla/5.0 (iPhone; CPU iPhone OS 16_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.6 Mobile/15E148 Safari/604.1"
  }.freeze

  setup do
    # A PUBLIC_URL exported in the shell would replace the request's base.
    @public_url = Rails.configuration.x.public_url
    Rails.configuration.x.public_url = nil
    OmniAuth.config.test_mode = true
    @sharer = accounts_players(:player)
    @sharer.update_columns(persona_name: "Gabe the Brave")
  end

  teardown do
    OmniAuth.config.mock_auth.delete(:steam)
    OmniAuth.config.test_mode = false
    Rails.configuration.x.public_url = @public_url
  end

  def card_page(locale: :en, slug: "blue-depths", number: 1)
    number ? card_season_path(locale:, slug:, number:) : card_path(locale:, slug:)
  end

  def season_url(locale: :en, slug: "blue-depths", number: 1, base: "http://www.example.com")
    "#{base}/#{locale}/cards/#{slug}/seasons/#{number}"
  end

  def meta(attribute, value) = css_select("head meta[#{attribute}='#{value}']").sole["content"]
  def og(property) = meta("property", "og:#{property}")
  def canonical = css_select("head link[rel=canonical]").sole["href"]

  test "a visitor sees the card only, then the invitation; no owner line or name, even for a card the sharer never held" do
    get card_page

    assert_response :success
    assert_select "main > .card-detail:first-child h1", "Blue Depths"
    assert_select "h1", 1
    assert_select ".card-detail__copies", false
    assert_select ".card-detail__share", false
    assert_select "main > .card-detail + .card-detail__invitation p.panel", "Ten packs wait in the attic, Brother. Open them, and the cards are yours."
    assert_select ".card-detail__invitation form[action='/auth/steam'] button", "Claim them through Steam"
    assert_select ".library, .profile", false
    assert_not_includes response.body, "Gabe the Brave"
    assert_no_match(/collection of|No longer in/i, response.body)
    assert_select ".top-bar__start > a.button--secondary[href='/en']", "Bridge"
  end

  test "the preview tags: title and rarity, a fixed line, the season URL, en_US, a summary card, no image" do
    get card_page

    assert_equal "Blue Depths — Rare", og("title")
    assert_select "title", "Blue Depths — Rare"
    description = "A card from the attic of the Brotherhood. Enlist through Steam, Brother: ten packs wait for you."
    assert_equal description, og("description")
    assert_equal description, meta("name", "description")
    assert_equal "website", og("type")
    assert_equal "gameble", og("site_name")
    assert_equal season_url, og("url")
    assert_equal season_url, canonical
    assert_equal "en_US", og("locale")
    assert_equal "summary", meta("name", "twitter:card")
    assert_equal "noindex", meta("name", "robots")
    # Never an image in the preview.
    assert_select "head meta[property^='og:image'], head meta[name^='twitter:image'], head meta[property^='twitter:image']", false
    assert_select "head link[rel=image_src], head meta[name=image_src]", false
    assert_no_match(/og:image|twitter:image|image_src/, css_select("head").sole.to_html)
  end

  test "in French: the French title and rarity, fr_FR, the French URL, the French invitation" do
    get card_page(locale: :fr)

    assert_equal "Profondeurs bleues — Rare", og("title")
    assert_select "title", "Profondeurs bleues — Rare"
    assert_equal "fr_FR", og("locale")
    assert_equal season_url(locale: :fr), og("url")
    assert_equal "Une carte du grenier de la Confrérie. Enrôle-toi via Steam, Confrère : dix paquets t'attendent.", og("description")
    assert_select ".card-detail__invitation p", "Dix paquets t'attendent au grenier, Confrère. Ouvre-les, et les cartes sont à toi."
    assert_select ".card-detail__invitation button", "Les réclamer via Steam"
  end

  test "the season-less page shows the published season, its canonical the season form, without query" do
    get "#{card_page(slug: "portal", number: nil)}?utm_source=discord"

    assert_response :success
    assert_select ".card-detail h1", "Portal"
    assert_equal season_url(slug: "portal"), canonical
    assert_equal season_url(slug: "portal"), og("url")
    assert_equal "Portal — Epic", og("title")
  end

  test "a season number in the query string is ignored" do
    get "#{card_page(number: nil)}?number=7"

    assert_response :success
    assert_equal season_url, og("url")
  end

  test "the absolute URLs come from the configured base, never from a spoofed Host" do
    Rails.configuration.x.public_url = "https://gameble.example"
    host! "evil.example"

    get card_page

    assert_response :success
    assert_equal season_url(base: "https://gameble.example"), og("url")
    assert_equal season_url(base: "https://gameble.example"), canonical
    assert_not_includes response.body, "evil.example"
  end

  test "a signed-in viewer, holder or not: the card, no invitation; a holder keeps their copies and the share block" do
    hold(@sharer, catalog_card_seasons(:rare_card_one).id, 2)
    viewer = accounts_players(:moderator)

    sign_in(viewer)
    get card_page
    assert_response :success
    assert_select ".card-detail__invitation", false
    assert_select ".card-detail__copies", false
    assert_select ".card-detail__share", false
    assert_equal "Blue Depths — Rare", og("title")
    delete session_path(locale: :en)

    sign_in(@sharer)
    get card_page
    assert_select ".card-detail__invitation", false
    assert_select ".card-detail__copies", "You hold 2 copies"
    assert_select ".card-detail__share input[value=?]", season_url
  end

  test "a visitor signing in from the invitation lands in the attic" do
    get card_page
    form = css_select(".card-detail__invitation form").sole
    origin = form.at_css("input[name=origin]")["value"]
    assert_equal "/en", origin

    newcomer = accounts_players(:moderator)
    OmniAuth.config.mock_auth[:steam] = OmniAuth::AuthHash.new(provider: "steam", uid: "https://steamcommunity.com/openid/id/#{newcomer.steam_id}")
    post form["action"], params: { origin: }
    follow_redirect!

    assert_redirected_to "/en"
    assert_equal newcomer.id, session[:player_id]
  end

  test "a share link of story 4.5 redirects to the card's page, whatever the token, without a query" do
    banned = accounts_players(:banned)

    [ @sharer.token, banned.token, "A" * 24 ].each do |token|
      assert_request_queries(0) { get "/en/brothers/#{token}/cards/portal/seasons/1" }
      assert_response :moved_permanently
      assert_redirected_to "/en/cards/portal/seasons/1"

      get "/fr/brothers/#{token}/cards/blue-depths?utm_source=discord"
      assert_response :moved_permanently
      assert_redirected_to "/fr/cards/blue-depths"
    end

    follow_redirect!
    assert_response :success
    assert_select ".card-detail h1", "Profondeurs bleues"
    assert_not_includes response.body, "Gabe the Brave"
  end

  test "an old share link redirects to the configured base, never to a spoofed Host, and opens the card with its tags" do
    Rails.configuration.x.public_url = "https://gameble.example"
    spoofed = { "Host" => "evil.example", "X-Forwarded-Host" => "evil.example" }

    get "/en/brothers/#{@sharer.token}/cards/portal/seasons/1", headers: spoofed
    assert_response :moved_permanently
    assert_equal "https://gameble.example/en/cards/portal/seasons/1", response.location

    assert_request_queries(0) { get "/en/brothers/#{@sharer.token}/cards/portal", headers: spoofed }
    assert_response :moved_permanently
    assert_equal "https://gameble.example/en/cards/portal", response.location
    assert_not_includes response.headers.to_h.values.join(" "), "evil.example"
  end

  test "an old share link, season-qualified or not, leads to the card's page and its preview tags" do
    [ [ "/en/brothers/#{@sharer.token}/cards/portal/seasons/1", "/en/cards/portal/seasons/1" ],
      [ "/en/brothers/#{@sharer.token}/cards/portal", "/en/cards/portal" ] ].each do |old, target|
      get old
      assert_redirected_to target
      follow_redirect!

      assert_response :success
      assert_equal target, path
      assert_equal "Portal — Epic", og("title")
      assert_equal season_url(slug: "portal"), og("url")
    end
  end

  test "an old share link with a malformed token or season number is not routed" do
    [ "/en/brothers/abcde/cards/portal", "/en/brothers/#{"0" * 24}/cards/portal", "/en/brothers/#{@sharer.token}/cards/portal/seasons/one" ].each do |path|
      get path
      assert_response :not_found, path
    end
  end

  test "the share links of story 4.5 have no route helper any more" do
    assert respond_to?(:card_season_path)
    assert_not respond_to?(:brother_card_path)
    assert_not respond_to?(:brother_card_season_path)
  end

  USER_AGENTS.each do |name, user_agent|
    test "#{name} gets the card's page with its tags, and the library its sets lead to" do
      get card_page(slug: "portal"), headers: { "User-Agent" => user_agent }

      assert_response :success
      assert_equal "Portal — Epic", og("title")
      set_link = css_select(".card-detail__sets a").sole["href"]

      get set_link, headers: { "User-Agent" => user_agent }
      assert_response :success
      get library_path(locale: :en), headers: { "User-Agent" => user_agent }
      assert_response :success
      head card_page(slug: "portal"), headers: { "User-Agent" => user_agent }
      assert_response :success
    end
  end

  test "the attic and the sessions still turn an old browser away" do
    old = { "User-Agent" => USER_AGENTS[:ios_16_safari] }

    get home_path(locale: :en), headers: old
    assert_response :not_acceptable

    get steam_callback_path, headers: old
    assert_response :not_acceptable

    delete session_path(locale: :en), headers: old
    assert_response :not_acceptable

    get card_page, headers: old
    assert_response :success
  end

  test "no database id reaches the page" do
    hold(@sharer, catalog_card_seasons(:rare_card_one).id, 2)
    ids = [ @sharer.id, catalog_card_seasons(:rare_card_one).id, catalog_cards(:rare_card).id, catalog_seasons(:one).id,
      catalog_sets(:valve_one).id ]

    get card_page

    assert_not_includes response.body, @sharer.steam_id
    assert_not_includes response.body, @sharer.token
    assert_select "main [data-id]", false
    html = css_select("main").sole.to_html.gsub(/\b(19|20)\d\d\b|[Ss]eason \d+|\/seasons\/\d+|data-card-art-(width|height)-value="\d+"|width="\d+"|height="\d+"/, "")
    ids.each do |id|
      next if id < 10 # a season number or a count would match

      assert_no_match(/\b#{id}\b/, html, "id #{id} on the page")
    end
    assert_no_match(/\b#{catalog_card_seasons(:rare_card_one).id}\b/, response.body)
  end
end
