require "test_helper"
require_relative "../support/catalog_seeds"
require_relative "../support/library_requests"
require_relative "../support/game_packs"
require_relative "../support/steam_sign_in"
require_relative "../support/share_image_art"

# A card's page as a share link opens it: only the card, never who shared
# or holds it; the preview tags (title and rarity, and the card's image
# once rendered, its render enqueued until then) in the URL's language, on
# the configured public base; for a visitor, the public card page with
# the invitation to play and, for an older browser, the line asking to
# update; open to link-preview crawlers and older browsers, with the
# library its sets lead to; the old share links, which named the sharer,
# redirected; no database id.
class CardPreviewTagsTest < ActionDispatch::IntegrationTest
  include CatalogSeeds
  include LibraryRequests
  include GamePacks
  include SteamSignIn
  include ShareImageArt

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
    @sharer = accounts_players(:player)
    @sharer.update_columns(persona_name: "Gabe the Brave")
  end

  teardown do
    Rails.configuration.x.public_url = @public_url
  end

  def card_page(locale: :en, slug: "blue-depths", number: 1)
    number ? card_season_path(locale:, slug:, number:) : card_path(locale:, slug:)
  end

  def season_url(locale: :en, slug: "blue-depths", number: 1, base: "http://www.example.com")
    "#{base}/#{locale}/cards/#{slug}/seasons/#{number}"
  end

  def meta(attribute, value) = css_select("head meta[#{attribute}='#{value}']").sole["content"]
  def image_tags = css_select("head meta[property^='og:image'], head meta[name^='twitter:image']")
  def rare_card_season_id = catalog_card_seasons(:rare_card_one).id
  def og(property) = meta("property", "og:#{property}")
  def canonical = css_select("head link[rel=canonical]").sole["href"]

  test "a visitor sees the public card page: the card only, the pitch and its one primary button; no owner line or name, even for a card the sharer never held" do
    get card_page

    assert_response :success
    assert_select "main > article.public-card h1#public-card-heading", "Blue Depths"
    assert_select "h1", 1
    assert_select ".public-card .card.card--xl.card--rarity-rare"
    assert_select ".public-card__publisher", false
    assert_select ".public-card__line", "Rare · 2014 · S1 · #3"
    assert_select ".card-detail, .card-detail__copies, #share-sheet, .card-detail__share", false
    assert_select ".public-card__pitch-title", "Your Steam games, as collectible cards."
    assert_select ".public-card__pitch-text", "Open capsules, complete sets, trade with your friends."
    assert_select ".public-card__pitch a.button--primary[href^='/en/sign-in']", "Open my first capsules"
    assert_select ".public-card__pitch [aria-haspopup]", false
    # The page's one primary action; "See on Steam" is a link.
    assert_select "main .button--primary", 1
    link = css_select("main a.public-card__store.button--link").sole
    assert_equal [ "See on Steam (new tab)", "noopener noreferrer external", "_blank" ], [ link.text.squish, link["rel"], link["target"] ]
    # The slim top bar: the wordmark leading to the landing (one for the
    # desktop, one for the phone) and the Steam sign-in image, no way back,
    # no tab bar.
    assert_select ".top-bar__start > a.top-bar__brand.top-bar__home[href='/en'] svg.pixel-icon.top-bar__wordmark"
    assert_select ".top-bar__start > a.top-bar__brand.top-bar__phone-brand[href='/en']"
    assert_select ".top-bar__start > a", 2
    assert_select ".top-bar__start p.top-bar__brand", false
    assert_select ".top-bar__end a[href^='/en/sign-in']"
    assert_select "nav.tab-bar", false
    assert_select "main a[href^='/en/sign-in']", 1
    assert_select ".public-card__live-title", /Live\s+·\s+Right now on Gameble/
    assert_select "#live-strip .public-card__live-empty", "Nothing here yet."
    assert_select ".public-card__footer a.public-card__legal[href=?]", "/en/legal", "Legal notice"
    assert_select ".library, .profile", false
    assert_not_includes response.body, "Gabe the Brave"
    assert_no_match(/collection of|No longer in/i, response.body)
  end

  test "the LIVE strip shows the three latest public feed entries and listens to the public stream" do
    hugo = accounts_players(:moderator).tap { it.update!(persona_name: "Hugo") }
    hidden = accounts_players(:administrator).tap { it.update!(persona_name: "Hidden") }
    create_pack(hugo, cards: [ catalog_card_seasons(:portal_one).id ] * 5)
    Game::OpenPack.new.call(player: hugo).value!
    create_pack(hidden, cards: [ catalog_card_seasons(:portal_one).id ] * 5)
    Game::OpenPack.new.call(player: hidden).value!
    hidden.update!(visibility: :private)
    # Their completion of the Valve set, older than the pulls.
    Game::FeedEntry.where(kind: "set").update_all(occurred_at: 1.hour.ago)

    get card_page(locale: :fr)

    assert_select "#live-strip .public-card__live-list > li.public-card__live-entry", 3 do |entries|
      entries.each { |entry| assert_equal "Hugo a tiré Portal", entry.at_css(".public-card__live-sentence").text }
    end
    assert_select "#live-strip .feed__tag--epic", count: 3, text: "Épique"
    assert_select "#live-strip", text: /Hidden/, count: 0
    assert_select "#live-strip [aria-hidden]", 0
    assert_equal [ "live:fr" ], css_select("turbo-cable-stream-source").map { Turbo::StreamsChannel.verified_stream_name(it["signed-stream-name"]) }
  end

  test "an older browser's line: in the markup beside the invitation, the stylesheet showing one or the other by :has() support, no script involved" do
    get card_page

    assert_select ".public-card__update", "Your browser is too old to sign in to Gameble. Update it to play."
    assert_select ".public-card__pitch"
    assert_select "script", text: /:has|userAgent|navigator/, count: 0

    css = %w[card-detail card-detail-stepping card-detail-public].sum("") { |name| Rails.root.join("app/frontend/styles/#{name}.css").read }
    default, supported = css.split("@supports selector(:has(*))", 2)
    # By default: the invitation and the sign-in image hidden, the line shown.
    assert_match(/\.public-card__pitch \{\s*display: none;/, default)
    assert_match(/\.is-public-page \.top-bar__end \{\s*display: none;/, default)
    assert_no_match(/\.public-card__update \{[^}]*display: none/, default)
    # Where :has() works: the invitation and the image shown, the line hidden.
    assert_match(/\.public-card__pitch \{\s*display: flex;/, supported)
    assert_match(/\.public-card__update \{\s*display: none;/, supported)
    assert_match(/\.is-public-page \.top-bar__end \{\s*display: flex;/, supported)
  end

  def assert_text_preview(locale: :en)
    assert_equal "Blue Depths — Rare", og("title") if locale == :en
    assert_equal "summary", meta("name", "twitter:card")
    assert_empty image_tags
    assert_select "head link[rel=image_src], head meta[name=image_src]", false
  end

  test "the preview tags: title and rarity, a fixed line, the season URL, en_US; before the image exists, a summary card and its render enqueued" do
    assert_enqueued_with(job: CardShareImageJob, args: [ rare_card_season_id, "en" ], queue: "share_images") { get card_page }

    assert_equal "Blue Depths — Rare", og("title")
    assert_select "title", "Blue Depths — Rare"
    description = "A card of Gameble, your Steam games as collectible cards. Sign in: ten capsules wait for you."
    assert_equal description, og("description")
    assert_equal description, meta("name", "description")
    assert_equal "website", og("type")
    assert_equal "Gameble", og("site_name")
    assert_equal season_url, og("url")
    assert_equal season_url, canonical
    assert_equal "en_US", og("locale")
    assert_select "head meta[name=robots]", false
    assert_text_preview
    assert_equal 0, Catalog::ShareImage.count
  end

  test "a current image: its absolute URL by token, its size, type and alt, a large card; the other tags unchanged" do
    token = store_share_image(rare_card_season_id, "en").token
    image_url = "http://www.example.com/share-images/#{token}.png"

    assert_no_enqueued_jobs(only: CardShareImageJob) { get card_page }

    assert_equal image_url, og("image")
    assert_equal "image/png", og("image:type")
    assert_equal [ "1200", "630" ], [ og("image:width"), og("image:height") ]
    assert_equal "The card Blue Depths (Rare) with its Steam art", og("image:alt")
    assert_equal "summary_large_image", meta("name", "twitter:card")
    assert_equal image_url, meta("name", "twitter:image")
    assert_equal "The card Blue Depths (Rare) with its Steam art", meta("name", "twitter:image:alt")
    assert_equal [ "Blue Depths — Rare", season_url, season_url, "en_US" ], [ og("title"), og("url"), canonical, og("locale") ]
    assert_select "head meta[name=robots]", false
    assert_equal 8, image_tags.size + css_select("head meta[name='twitter:card']").size

    get image_url
    assert_response :success
    assert_equal "image/png", response.media_type
  end

  test "each language has its own image; the French page names the card in French" do
    store_share_image(rare_card_season_id, "en")
    french = store_share_image(rare_card_season_id, "fr").token

    get card_page(locale: :fr)

    assert_equal "http://www.example.com/share-images/#{french}.png", og("image")
    assert_equal "La carte Profondeurs bleues (Rare) avec son illustration Steam", og("image:alt")
    assert_equal [ "Profondeurs bleues — Rare", "fr_FR" ], [ og("title"), og("locale") ]
  end

  test "an image of the card as it was gives the text preview and enqueues its render again" do
    store_share_image(rare_card_season_id, "en", fingerprint: "e" * 64)

    assert_enqueued_with(job: CardShareImageJob, args: [ rare_card_season_id, "en" ]) { get card_page }

    assert_text_preview
  end

  test "an image whose file is lost gives the text preview and enqueues its render on the share images queue" do
    lost = store_share_image(rare_card_season_id, "en")
    ActiveStorage::Blob.service.delete(lost.image.blob.key)

    assert_enqueued_with(job: CardShareImageJob, args: [ rare_card_season_id, "en" ], queue: "share_images") { get card_page }

    assert_response :success
    assert_text_preview
  end

  test "the image URL comes from the configured base and holds the token only" do
    Rails.configuration.x.public_url = "https://gameble.example"
    host! "evil.example"
    token = store_share_image(rare_card_season_id, "en").token

    get card_page

    assert_equal "https://gameble.example/share-images/#{token}.png", og("image")
    assert_equal og("image"), meta("name", "twitter:image")
  end

  test "a signed-in viewer's page renders no image either and writes nothing: the render waits in the queue" do
    sign_in(@sharer)

    assert_no_difference [ "Catalog::ShareImage.count", "ActiveStorage::Blob.count" ] do
      assert_enqueued_jobs(1, only: CardShareImageJob) { get card_page }
    end
    assert_response :success
    assert_text_preview
  end

  test "in French: the French title and rarity, fr_FR, the French URL, the French invitation" do
    get card_page(locale: :fr)

    assert_equal "Profondeurs bleues — Rare", og("title")
    assert_select "title", "Profondeurs bleues — Rare"
    assert_equal "fr_FR", og("locale")
    assert_equal season_url(locale: :fr), og("url")
    assert_equal "Une carte de Gameble, vos jeux Steam en cartes à collectionner. Connectez-vous : dix capsules vous attendent.", og("description")
    assert_select ".public-card__pitch-title", "Vos jeux Steam, en cartes à collectionner."
    assert_select ".public-card__pitch-text", "Ouvrez des capsules, complétez des sets, échangez avec vos amis."
    assert_select ".public-card__pitch a.button--primary", "Ouvrir mes premières capsules"
    assert_select ".public-card__update", "Votre navigateur est trop ancien pour se connecter à Gameble. Mettez-le à jour pour jouer."
    assert_select ".public-card__live-title", /En ce moment sur Gameble/
    assert_select ".public-card__legal", "Mentions légales"
  end

  test "the season-less page shows the published season, its canonical the season form, without query" do
    get "#{card_page(slug: "portal", number: nil)}?utm_source=discord"

    assert_response :success
    assert_select ".public-card h1", "Portal"
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

  test "a signed-in viewer, holder or not: the card, no invitation, the share sheet; a holder keeps their copies" do
    hold(@sharer, catalog_card_seasons(:rare_card_one).id, 2)
    viewer = accounts_players(:moderator)

    sign_in(viewer)
    get card_page
    assert_response :success
    assert_select ".card-invitation", false
    assert_select ".card-detail__copies", "None"
    assert_select ".card-detail__share-button", "Share"
    assert_select "#share-sheet input[value=?]", season_url
    # The card's own page shows the face to a viewer who does not hold it.
    assert_select ".card-detail__card .card.card--l"
    assert_equal "Blue Depths — Rare", og("title")
    delete session_path(locale: :en)

    sign_in(@sharer)
    get card_page
    assert_select ".card-invitation", false
    assert_select ".card-detail__copies", "2 copies"
    assert_select "#share-sheet input[value=?]", season_url
  end

  test "a visitor signing in from the pitch lands on the hub" do
    get card_page
    link = css_select(".public-card__pitch a[href^='/en/sign-in']").sole
    get link["href"]
    form = css_select("form.steam-sign-in[action='/auth/steam']").sole
    origin = form.at_css("input[name=origin]")["value"]
    assert_equal URI(card_page).path, origin

    newcomer = accounts_players(:moderator)
    mock_steam_sign_in(newcomer.steam_id)
    post form["action"], params: { origin: }
    follow_redirect!

    assert_redirected_to "/en"
    assert_equal newcomer.id, session[:player_id]
  end

  test "an old share link redirects to the card's page, whatever the token, without a query" do
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
    assert_select ".public-card h1", "Profondeurs bleues"
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

  test "the old share links have no route helper" do
    assert respond_to?(:card_season_path)
    assert_not respond_to?(:brother_card_path)
    assert_not respond_to?(:brother_card_season_path)
  end

  USER_AGENTS.each do |name, user_agent|
    test "#{name} gets the card's page with its tags and the grid of every card; the albums lead it to the landing" do
      get card_page(slug: "portal"), headers: { "User-Agent" => user_agent }

      assert_response :success
      assert_equal "Portal — Epic", og("title")

      get library_set_path(locale: :en, kind: "studio", key: "valve"), headers: { "User-Agent" => user_agent }
      assert_redirected_to home_path(locale: :en)
      get library_path(locale: :en), headers: { "User-Agent" => user_agent }
      assert_redirected_to home_path(locale: :en)
      get home_path(locale: :en), headers: { "User-Agent" => user_agent }
      assert_response :success
      get library_cards_path(locale: :en), headers: { "User-Agent" => user_agent }
      assert_response :success
      head card_page(slug: "portal"), headers: { "User-Agent" => user_agent }
      assert_response :success
    end
  end

  test "the player's screens and the sessions still turn an old browser away, the landing does not" do
    old = { "User-Agent" => USER_AGENTS[:ios_16_safari] }

    get more_path(locale: :en), headers: old
    assert_response :not_acceptable

    get home_path(locale: :en), headers: old
    assert_response :success

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
