require "test_helper"
require_relative "../support/catalog_seeds"
require_relative "../support/library_requests"

# A card shared from a player's collection (CAP-9, story 4.5): the owner's
# profile with the card's detail first, the owner line (or "no longer
# there"), the invitation for a visitor only; the preview tags (title and
# rarity, never an image) in the URL's language, on the configured public
# base; open to link-preview crawlers and older browsers; the unavailable
# page and the cards not found; the queries of a request; no database id.
class PublicProfilesCardTest < ActionDispatch::IntegrationTest
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
    @owner = accounts_players(:player)
    @owner.update_columns(persona_name: "Gabe the Brave")
    @sapphire = catalog_card_seasons(:sapphire_card_one)
  end

  teardown do
    OmniAuth.config.mock_auth.delete(:steam)
    OmniAuth.config.test_mode = false
    Rails.configuration.x.public_url = @public_url
  end

  def card_page(locale: :en, slug: "blue-depths", number: nil, token: @owner.token)
    number ? brother_card_season_path(locale:, token:, slug:, number:) : brother_card_path(locale:, token:, slug:)
  end

  def season_url(locale: :en, slug: "blue-depths", number: 1, base: "http://www.example.com")
    "#{base}/#{locale}/brothers/#{@owner.token}/cards/#{slug}/seasons/#{number}"
  end

  def meta(attribute, value) = css_select("head meta[#{attribute}='#{value}']").sole["content"]
  def og(property) = meta("property", "og:#{property}")
  def canonical = css_select("head link[rel=canonical]").sole["href"]

  test "a visitor sees the owner's profile with the card's detail first, the owner line and the invitation" do
    hold(@owner, @sapphire.id, 1)

    get card_page(number: 1)

    assert_response :success
    assert_select ".shared-card > .card-detail:first-child h1", "Blue Depths"
    assert_select "h1", 1
    assert_select ".card-detail__owner", "From the collection of Gabe the Brave"
    assert_select ".card-detail__owner--gone", false
    assert_select ".card-detail__copies", false
    assert_select ".card-detail__share", false
    assert_select ".shared-card__invitation p.text-plate", "Ten packs wait in the attic, Brother. Open them, and the cards are yours."
    assert_select ".shared-card__invitation form[action='/auth/steam'] button", "Claim them through Steam"
    # Then the owner's profile, named by an h2 under the card's title.
    assert_select ".shared-card > .card-detail + .shared-card__invitation + .library.profile h2#library-heading", "Gabe the Brave"
    assert_select ".profile__counts li", "1 card collected"
    assert_select ".library__tab[aria-current=page]", "Started"
    assert_select ".status-band > a.button--secondary[href='/en']", "Back to the attic"
  end

  test "the preview tags: title and rarity, a fixed line, the season URL, en_US, a summary card, no image" do
    hold(@owner, @sapphire.id, 1)

    get card_page(number: 1)

    assert_equal "Blue Depths — Sapphire", og("title")
    assert_select "title", "Blue Depths — Sapphire"
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

  test "in French: the French title and rarity, fr_FR, the French URL" do
    hold(@owner, @sapphire.id, 1)

    get card_page(locale: :fr, number: 1)

    assert_equal "Profondeurs bleues — Saphir", og("title")
    assert_select "title", "Profondeurs bleues — Saphir"
    assert_equal "fr_FR", og("locale")
    assert_equal season_url(locale: :fr), og("url")
    assert_equal "Une carte du grenier de la Confrérie. Enrôle-toi via Steam, Confrère : dix paquets t'attendent.", og("description")
    assert_select ".card-detail__owner", "De la collection de Gabe the Brave"
    assert_select ".shared-card__invitation button", "Les réclamer via Steam"
  end

  test "the season-less link shows the published season, its canonical the season form, without query" do
    hold(@owner, catalog_card_seasons(:portal_one).id, 1)

    get "#{card_page(slug: "portal")}?utm_source=discord"

    assert_response :success
    assert_select ".card-detail h1", "Portal"
    assert_equal season_url(slug: "portal"), canonical
    assert_equal season_url(slug: "portal"), og("url")
    assert_equal "Portal — Amethyst", og("title")
  end

  test "the card's sets lead to the owner's tomes" do
    hold(@owner, catalog_card_seasons(:portal_one).id, 1)

    get card_page(slug: "portal", number: 1)

    assert_equal [ [ "Valve", "/en/brothers/#{@owner.token}/library/publisher/valve" ] ],
      css_select(".card-detail__sets a").map { [ it.text, it["href"] ] }
  end

  test "an owner who no longer holds the card: the detail says so, 200" do
    hold(@owner, @sapphire.id, 0)

    get card_page(number: 1)

    assert_response :success
    assert_select ".card-detail h1", "Blue Depths"
    assert_select ".card-detail__owner.card-detail__owner--gone", "No longer in Gabe the Brave's collection"
    assert_select ".card-detail__owner:not(.card-detail__owner--gone)", false

    get card_page(slug: "golden-crown", number: 1)
    assert_response :success
    assert_select ".card-detail__owner--gone", "No longer in Gabe the Brave's collection"
  end

  test "a signed-in viewer, the owner or not: the detail and owner line, no invitation, no share button, no copies" do
    hold(@owner, @sapphire.id, 2)
    viewer = accounts_players(:moderator)
    hold(viewer, @sapphire.id, 3)

    [ viewer, @owner ].each do |player|
      sign_in(player)
      get card_page(number: 1)

      assert_response :success
      assert_select ".card-detail__owner", "From the collection of Gabe the Brave"
      assert_select ".shared-card__invitation", false
      assert_select ".card-detail__share", false
      assert_select ".card-detail__copies", false
      assert_no_match(/You hold/, response.body)
      delete session_path(locale: :en)
    end
  end

  test "a visitor signing in from the invitation lands in the attic" do
    hold(@owner, @sapphire.id, 1)
    get card_page(number: 1)
    form = css_select(".shared-card__invitation form").sole
    origin = form.at_css("input[name=origin]")["value"]
    assert_equal "/en", origin

    newcomer = accounts_players(:moderator)
    OmniAuth.config.mock_auth[:steam] = OmniAuth::AuthHash.new(provider: "steam", uid: "https://steamcommunity.com/openid/id/#{newcomer.steam_id}")
    post form["action"], params: { origin: }
    follow_redirect!

    assert_redirected_to "/en"
    assert_equal newcomer.id, session[:player_id]
  end

  test "an unknown token or a banned owner shows the unavailable page, even with a bad slug" do
    hold(@owner, @sapphire.id, 1)
    banned = accounts_players(:banned)
    hold(banned, @sapphire.id, 1)

    [ card_page(token: "A" * 24), card_page(token: banned.token, number: 1), card_page(token: banned.token, slug: "nope"),
      card_page(token: banned.token, slug: "nope", number: 7) ].each do |path|
      get path
      assert_response :not_found, path
      assert_select "h1", "Profile not available"
    end
  end

  test "an unknown slug, a numeric slug, a card id or an unknown season is not found" do
    hold(@owner, @sapphire.id, 1)
    token = @owner.token

    [ "/en/brothers/#{token}/cards/nope", "/en/brothers/#{token}/cards/123", "/en/brothers/#{token}/cards/#{catalog_cards(:sapphire_card).id}",
      "/en/brothers/#{token}/cards/blue-depths/seasons/2", "/en/brothers/#{token}/cards/blue-depths/seasons/0",
      "/en/brothers/#{token}/cards/blue-depths/seasons/one", "/en/brothers/abcde/cards/blue-depths" ].each do |path|
      get path
      assert_response :not_found, path
      assert_select "h1", { text: "Profile not available", count: 0 }, path
    end
  end

  test "a season number in the query string is ignored" do
    hold(@owner, @sapphire.id, 1)

    get "#{card_page}?number=7"

    assert_response :success
    assert_equal season_url, og("url")
  end

  test "the absolute URLs come from the configured base, never from a spoofed Host" do
    hold(@owner, @sapphire.id, 1)
    Rails.configuration.x.public_url = "https://gameble.example"
    host! "evil.example"

    get card_page(number: 1)

    assert_response :success
    assert_equal season_url(base: "https://gameble.example"), og("url")
    assert_equal season_url(base: "https://gameble.example"), canonical
    assert_not_includes response.body, "evil.example"
  end

  USER_AGENTS.each do |name, user_agent|
    test "#{name} gets the page with its tags" do
      hold(@owner, @sapphire.id, 1)

      get card_page(number: 1), headers: { "User-Agent" => user_agent }

      assert_response :success
      assert_equal "Blue Depths — Sapphire", og("title")
    end
  end

  test "the other pages still turn an old browser away" do
    get card_path(locale: :en, slug: "blue-depths"), headers: { "User-Agent" => USER_AGENTS[:ios_16_safari] }
    assert_response :not_acceptable

    get brother_path(locale: :en, token: @owner.token), headers: { "User-Agent" => USER_AGENTS[:discord_firefox] }
    assert_response :success
  end

  test "a visitor's shared card costs ten queries, a signed-in viewer's one more" do
    hold(@owner, catalog_card_seasons(:portal_one).id, 1)

    # Owner by token, card detail, its sets, the owner's quantity, published
    # season, shelf count, shelf page, totals, progress, summary.
    assert_request_queries(10) { get card_page(slug: "portal", number: 1) }
    assert_response :success
    assert_select ".shelf .tome", 1

    sign_in(accounts_players(:moderator))
    # The same, and the viewer's lookup.
    assert_request_queries(11) { get card_page(slug: "portal", number: 1) }
    assert_response :success
  end

  test "no database id reaches the page; the token only in URLs" do
    hold(@owner, @sapphire.id, 2)
    ids = [ @owner.id, @sapphire.id, catalog_cards(:sapphire_card).id, catalog_seasons(:one).id, catalog_sets(:valve_one).id ]

    get card_page(number: 1)

    assert_not_includes response.body, @owner.steam_id
    assert_select ".shared-card [data-id]", false
    without_urls = response.body.gsub(/(href|action|value|content)="[^"]*"/, "")
    assert_not_includes without_urls, @owner.token
    html = css_select("main").sole.to_html.gsub(/\b(19|20)\d\d\b|\d+ cards?|\d+ sets?|\d+ \/ \d+|\d+ of \d+|[Ss]eason \d+|\/seasons\/\d+|data-card-art-(width|height)-value="\d+"|width="\d+"|height="\d+"/, "")
    ids.each do |id|
      next if id < 10 # a season number or a count would match

      assert_no_match(/\b#{id}\b/, html, "id #{id} on the page")
    end
    assert_no_match(/\b#{@sapphire.id}\b/, response.body)
  end
end
