require "test_helper"
require_relative "../support/catalog_seeds"
require_relative "../support/game_sets"
require_relative "../support/library_requests"
require_relative "../support/steam_sign_in"

class PublicProfilesControllerTest < ActionDispatch::IntegrationTest
  include CatalogSeeds
  include GameSets
  include LibraryRequests
  include SteamSignIn

  setup do
    @owner = accounts_players(:player)
    @owner.update_columns(persona_name: "Gabe the Brave")
  end

  def album_count = css_select(".set-album__count").sole.text.squish

  # The figures of a block as [ label, value ].
  def figures(scope) = css_select("#{scope} .profile-figure").map { [ it.at_css("dt").text.squish, it.at_css("dd").text.squish ] }
  def keys = figures(".profile-band__keys")
  def key(label) = keys.to_h.fetch(label)

  # The started sets as [ name, "owned/total", href ].
  def set_rows
    css_select(".profile-sets .set-row").map { [ it.at_css(".set-row__name").text, it.at_css(".set-row__count").text, it["href"] ] }
  end

  def card_total(season) = Catalog::CardSeason.where(season_id: season.id).where.not(rarity: nil).count

  def unlock(key, at) = Game::AchievementUnlock.create!(player_id: @owner.id, achievement: key, unlocked_at: at)

  def written_statements(&request)
    statements = []
    record = ->(*, payload) { statements << payload[:sql] if payload[:sql].match?(/\A\s*(INSERT|UPDATE|DELETE)\b/i) }
    ActiveSupport::Notifications.subscribed(record, "sql.active_record", &request)
    statements
  end

  # All of Pirates (complete), so half of Horror; two of RPG, both also
  # Roguelike; and one UFO.
  def hold_started_sets(season)
    set_members(season, "pirates").each { hold(@owner, it, 1) }
    set_members(season, "rpg").first(2).each { hold(@owner, it, 1) }
    hold(@owner, set_members(season, "ufos").first, 1)
  end

  def open_packs(season, count)
    card = set_members(season, "rpg").first
    count.times do
      Game::Pack.create!(player_id: @owner.id, kind: :regular, season_id: season.id, card_season_ids: Array.new(Game::Pack::SIZE, card),
        available_at: 1.hour.ago, opened_at: 1.hour.ago)
    end
  end

  def conclude_trade_with(partner)
    low, high = [ @owner.id, partner.id ].minmax
    Game::Trade.create!(low_player_id: low, high_player_id: high, proposer_id: partner.id, recipient_id: @owner.id, status: "accepted",
      proposed_at: 1.day.ago, expires_at: 6.days.from_now)
  end

  test "a visitor sees the identity band, the stats, the latest achievements and the started sets, complete first then by share, and the GET writes nothing" do
    season = publish_sets_draft
    hold_started_sets(season)
    @owner.update_columns(created_at: Time.zone.local(2026, 3, 14, 12))
    { "first_booster" => 5, "first_epic" => 4, "first_complete_set" => 1, "boosters_10" => 2, "first_trade" => 3 }.each { |key, days| unlock(key, days.days.ago) }
    open_packs(season, 2)
    Game::FirstDiscovery.create!(card_season_id: set_members(season, "pirates").first, player_id: @owner.id, discovered_at: Time.current)
    conclude_trade_with(accounts_players(:moderator))

    written = written_statements { get brother_path(locale: :en, token: @owner.token) }

    assert_response :success
    assert_empty written
    assert_select "title", "Gabe the Brave"
    assert_select "h1", 1
    assert_select "h1#profile-heading", "Gabe the Brave"
    assert_select ".top-bar__title", "Gabe the Brave"
    assert_select "meta[name=robots][content=noindex]"
    assert_select "header.profile-band.panel--brackets svg.profile-band__avatar[aria-hidden=true]"
    assert_select ".profile-band__since", "Member since March 2026"
    assert_select ".profile-band button[data-dialog-opener-dialog-value=sign-in-panel]", "REPORT"
    assert_equal [ [ "Cards", "11/#{card_total(season)}" ], [ "Complete sets", "1" ], [ "Achievements", "5/10" ] ], keys

    assert_select "section.profile-stats[aria-label=Statistics]"
    rarities = figures(".profile-stats__grid--rarities")
    assert_equal [ "Common", "Uncommon", "Rare", "Epic", "Legendary" ], rarities.map(&:first)
    assert_equal 11, rarities.sum { it.last.to_i }
    assert_select ".profile-stats__grid--rarities .profile-figure--rarity-5 svg.profile-figure__icon"
    assert_equal [ [ "Capsules opened", "2" ], [ "First discoveries", "1" ], [ "Trades concluded", "1" ] ],
      figures(".profile-stats__grid:not(.profile-stats__grid--rarities)")

    assert_equal [ "Achievements", "Sets" ], css_select("h2").map(&:text)
    assert_select "#profile-achievements-heading ~ .achievements__head .visually-hidden", "5 achievements earned out of 10"
    assert_select "#profile-achievements-heading ~ .achievements__head .achievements__segment--lit", 5
    assert_select ".profile-section__label", "Latest earned"
    assert_equal [ "First complete set", "10 capsules", "First trade", "First Epic" ],
      css_select(".profile-achievements .achievement__name").map(&:text)
    assert_select ".profile-achievements .achievement--locked, .profile-achievements .achievement__bar", false

    assert_select ".profile-section__aside", "5 sets started"
    rows = set_rows
    assert_equal [ "8/8", "8/16", "1/15", "2/44", "2/119" ], rows.map(&:second)
    assert_equal [ "Pirates", "8/8", "/en/brothers/#{@owner.token}/library/theme/pirates" ], rows.first
    assert_equal [ "Horror", "8/16", "/en/brothers/#{@owner.token}/library/theme/horror" ], rows.second
    assert_select ".profile-sets .set-row--complete .set-tier--complete", 1

    assert_select ".set-search, .set-entry", false
    assert_select "[style]", false
  end

  test "the owner's own profile has no SIGNALER" do
    publish_sets_draft
    sign_in(@owner)

    get brother_path(locale: :en, token: @owner.token)

    assert_response :success
    assert_select ".profile-band button", false
    assert_select "#report-dialog", false
  end

  test "fewer than four achievements earned: as many tiles" do
    publish_sets_draft
    unlock("first_booster", 2.days.ago)
    unlock("first_epic", 1.day.ago)

    get brother_path(locale: :en, token: @owner.token)

    assert_equal [ "First Epic", "First capsule" ], css_select(".profile-achievements .achievement__name").map(&:text)
  end

  test "the owner's figures, never the viewer's" do
    season = publish_sets_draft
    set_members(season, "horror").first(2).each { |id| hold(@owner, id, 1) }
    viewer = accounts_players(:moderator)
    set_members(season, "rpg").first(5).each { |id| hold(viewer, id, 1) }
    sign_in(viewer)

    get brother_path(locale: :en, token: @owner.token)

    assert_equal "2/#{card_total(season)}", key("Cards")
    assert_not_includes set_rows.map(&:first), "RPG"
    assert_includes set_rows, [ "Horror", "2/16", "/en/brothers/#{@owner.token}/library/theme/horror" ]

    get brother_set_path(locale: :en, token: @owner.token, kind: "theme", key: "rpg")
    assert_select ".set-album__grid .card", (set_members(season, "rpg") & set_members(season, "horror").first(2)).size
  end

  test "a new owner: zeros, an unlit gauge with no latest tiles, the zero sets line and no rows" do
    season = publish_sets_draft

    get brother_path(locale: :en, token: @owner.token)

    assert_response :success
    assert_equal [ [ "Cards", "0/#{card_total(season)}" ], [ "Complete sets", "0" ], [ "Achievements", "0/10" ] ], keys
    assert_equal [ 0 ] * 5, figures(".profile-stats__grid--rarities").map { it.last.to_i }
    assert_select ".achievements__segment", 10
    assert_select ".achievements__segment--lit", false
    assert_select ".profile-section__label, .profile-achievements", false
    assert_select ".profile-section__aside", "0 sets started"
    assert_select ".profile-sets", false
  end

  test "with no season published the band shows zero cards and the no-season line stands for the rest" do
    catalog_seasons(:one).update_columns(status: "draft", published_at: nil)

    get brother_path(locale: :en, token: @owner.token)

    assert_response :success
    assert_select ".profile__no-season", "No season of cards is published yet."
    assert_equal [ [ "Cards", "0" ], [ "Complete sets", "0" ], [ "Achievements", "0/10" ] ], keys
    assert_select ".profile-stats, .profile-section", false
  end

  test "a signed-out visitor opens an owner's album: the owner's faces and copies, read-only, under the set and the owner's names" do
    season = publish_sets_draft
    members = set_members(season, "horror")
    [ 0, 3, 7, 12, 14, 15 ].each { hold(@owner, members[it], it == 3 ? 2 : 1, gained_at: 1.minute.ago) }

    get brother_set_path(locale: :en, token: @owner.token, kind: "theme", key: "horror")

    assert_response :success
    assert_select "title", "Horror · Gabe the Brave · gameble"
    assert_select "meta[name=robots][content=noindex]"
    assert_select "h1", 1
    assert_select "h1#set-album-heading[tabindex='-1']", "Horror · Gabe the Brave"
    assert_equal "6/16", album_count
    assert_equal "6 cards out of 16, expert tier", css_select("progress.set-album__bar").sole["aria-valuetext"]
    assert_select ".set-album__gauge, .set-album__kind", false
    assert_select "ol.set-album__grid.collection-grid--fill .card.card--grid", 6
    assert_select ".card--m", false
    assert_equal [ "x2" ], css_select(".collection-slot__copies").map(&:text)
    assert_select ".missing-slot .visually-hidden", { count: 10, text: "Missing card" }
    assert_select ".collection-slot__new", false
    assert_select ".top-bar__end .collection-status, .top-bar__title", false
    assert_select ".profile-band, .collection-kind, .collection-sets", false
    assert_select "[style]", false
    slugs = Catalog::CardSeason.where(id: members).includes(:card).index_by(&:id).transform_values { it.card.slug }
    assert_equal members.map { "/en/cards/#{slugs.fetch(it)}/seasons/#{season.number}?brother=#{@owner.token}&set_key=horror&set_kind=theme" },
      css_select(".set-album__grid > li > a.card-link").map { it["href"] }
  end

  test "an owner's album shows their earlier editions and their copies of every edition" do
    season = publish_sets_draft
    members = set_members(season, "pirates")
    older = Catalog::CardSeason.find(members[1])
    earlier = Catalog::CardSeason.insert_all!([ { card_id: older.card_id, season_id: catalog_seasons(:one).id, prestige_score: 0.5, rating: 80.0,
      rarity: Catalog::Rarity::TIERS.key(:legendary), number: 900 } ], returning: :id).rows.flatten.sole
    hold(@owner, earlier, 1)
    hold(@owner, members[1], 2)

    get brother_set_path(locale: :fr, token: @owner.token, kind: "theme", key: "pirates")

    assert_equal "1/8", album_count
    slot = css_select(".set-album__grid > li")[1]
    assert_equal "/fr/cards/#{older.card.slug}/seasons/#{season.number}?brother=#{@owner.token}&set_key=pirates&set_kind=theme", slot.at_css("a.card-link")["href"]
    assert_equal "x3", slot.at_css(".collection-slot__copies").text
    assert_equal "1 carte sur 8", css_select("progress.set-album__bar").sole["aria-valuetext"]
  end

  test "an owner's album costs seven queries for a visitor, a signed-in viewer's five more" do
    season = publish_sets_draft
    hold(@owner, set_members(season, "rpg").first, 1)

    # Owner by token, published season; the album: its set, members and
    # tiers, the owner's editions, the page's card views.
    assert_request_queries(7) { get brother_set_path(locale: :en, token: @owner.token, kind: "theme", key: "rpg") }
    assert_response :success

    sign_in(accounts_players(:moderator))
    # The same, the viewer's lookup, the top bar's three and the trades
    # waiting.
    assert_request_queries(12) { get brother_set_path(locale: :en, token: @owner.token, kind: "theme", key: "rpg") }
    assert_response :success
  end

  test "a wrong kind, an unknown key or a key of another kind is not found under a profile" do
    publish_sets_draft

    get "/en/brothers/#{@owner.token}/library/nope/rpg"
    assert_response :not_found

    get brother_set_path(locale: :en, token: @owner.token, kind: "theme", key: "action")
    assert_response :not_found

    get brother_set_path(locale: :en, token: @owner.token, kind: "studio", key: "rpg")
    assert_response :not_found
  end

  test "with no season published no set is found under a profile" do
    catalog_seasons(:one).update_columns(status: "draft", published_at: nil)

    get brother_set_path(locale: :en, token: @owner.token, kind: "theme", key: "rpg")
    assert_response :not_found
  end

  test "an unknown token shows the unavailable page with a 404, after one lookup" do
    publish_sets_draft

    assert_request_queries(1) { get brother_path(locale: :en, token: "A" * 24) }

    assert_response :not_found
    assert_select "title", "Profile not available"
    assert_select "h1", "Profile not available"
    assert_select "meta[name=robots][content=noindex]"
    assert_select ".collection, .collection-sets", false

    get brother_set_path(locale: :en, token: "A" * 24, kind: "theme", key: "rpg")
    assert_response :not_found
    assert_select "h1", "Profile not available"
  end

  test "a malformed token is a routing 404, with no query" do
    assert_request_queries(0) { get "/en/brothers/abcde" }
    assert_response :not_found

    # 0, O, I and l are not base58.
    get "/en/brothers/#{"0" * 24}"
    assert_response :not_found
    get "/en/brothers/#{"A" * 25}"
    assert_response :not_found
  end

  test "a banned owner's profile is the same unavailable page as an unknown token" do
    publish_sets_draft
    banned = accounts_players(:banned)
    banned.update_columns(persona_name: "Banned Brother")

    get brother_path(locale: :en, token: "A" * 24)
    unknown = css_select("main").to_html

    get brother_path(locale: :en, token: banned.token)
    assert_response :not_found
    assert_equal unknown, css_select("main").to_html
    assert_select "title", "Profile not available"
    assert_not_includes response.body, "Banned Brother"

    get brother_set_path(locale: :en, token: banned.token, kind: "theme", key: "rpg")
    assert_response :not_found
    assert_equal unknown, css_select("main").to_html
  end

  test "a profile banned by a moderator is the unavailable page, and shows again once unbanned" do
    publish_sets_draft
    moderator = accounts_players(:moderator)

    Accounts::BanPlayer.new.call(staff: moderator, player: @owner, reason: "Cheating").value!
    get brother_path(locale: :en, token: @owner.token)

    assert_response :not_found
    assert_select "title", "Profile not available"
    assert_not_includes response.body, "Gabe the Brave"

    Accounts::UnbanPlayer.new.call(staff: moderator, player: @owner).value!
    get brother_path(locale: :en, token: @owner.token)

    assert_response :success
    assert_includes response.body, "Gabe the Brave"
  end

  test "a private or friends-only owner is the unavailable page for a visitor and a stranger, not for the owner" do
    publish_sets_draft
    stranger = Accounts::Player.create!(steam_id: "76561197960390101")
    get brother_path(locale: :en, token: "A" * 24)
    unknown = css_select("main").to_html

    %w[private friends_only].each do |visibility|
      @owner.update!(visibility:)

      get brother_path(locale: :en, token: @owner.token)
      assert_response :not_found
      assert_equal unknown, css_select("main").to_html, visibility

      get brother_set_path(locale: :en, token: @owner.token, kind: "theme", key: "rpg")
      assert_response :not_found
      assert_equal unknown, css_select("main").to_html, visibility

      sign_in(stranger)
      get brother_path(locale: :en, token: @owner.token)
      assert_response :not_found
      delete session_path(locale: :en)

      sign_in(@owner)
      get brother_path(locale: :en, token: @owner.token)
      assert_response :success
      delete session_path(locale: :en)
    end
  end

  test "a friends-only owner is shown to a friend, a private one is not" do
    publish_sets_draft
    friend = Accounts::Player.create!(steam_id: "76561197960390102")
    Game::Friendship.create!(low_player_id: [ @owner.id, friend.id ].min, high_player_id: [ @owner.id, friend.id ].max)
    @owner.update!(visibility: "friends_only")
    sign_in(friend)

    get brother_path(locale: :en, token: @owner.token)
    assert_response :success
    assert_select "h1", "Gabe the Brave"

    @owner.update!(visibility: "private")
    get brother_path(locale: :en, token: @owner.token)
    assert_response :not_found
  end

  test "staff read a private, a friends-only and a banned owner's profile, a deleted one's not" do
    publish_sets_draft
    banned = accounts_players(:banned)
    banned.update_columns(persona_name: "Banned Brother")

    [ :moderator, :administrator ].each do |role|
      sign_in(accounts_players(role))

      %w[private friends_only].each do |visibility|
        @owner.update!(visibility:)
        get brother_path(locale: :en, token: @owner.token)
        assert_response :success, [ role, visibility ]
        assert_select "h1", "Gabe the Brave"
        get brother_set_path(locale: :en, token: @owner.token, kind: "theme", key: "rpg")
        assert_response :success, [ role, visibility ]
      end

      get brother_path(locale: :en, token: banned.token)
      assert_response :success, role
      assert_select "h1", "Banned Brother"
      delete session_path(locale: :en)
    end

    sign_in(accounts_players(:moderator))
    Accounts::DeletePlayer.new.call(player: @owner).value!
    get brother_path(locale: :en, token: @owner.reload.token)
    assert_response :not_found
    assert_select "h1", "Profile not available"
  end

  test "the profile carries no visibility line, for its owner, a visitor or staff on a banned player's" do
    publish_sets_draft
    banned = accounts_players(:banned)
    banned.update_columns(persona_name: "Banned Brother")

    get brother_path(locale: :en, token: @owner.token)
    assert_no_match(/Visible to|moderation team/, response.body)

    @owner.update!(visibility: "private")
    sign_in(@owner)
    get brother_path(locale: :fr, token: @owner.token)
    assert_response :success
    assert_no_match(/Profil privé|modération le voyez/, response.body)
    delete session_path(locale: :en)

    sign_in(accounts_players(:moderator))
    get brother_path(locale: :fr, token: banned.token)
    assert_response :success
    assert_select "h1", "Banned Brother"
    assert_no_match(/Joueur banni/, response.body)
  end

  test "a banned member of staff reads a hidden profile as the visitor they become" do
    publish_sets_draft
    moderator = accounts_players(:moderator)
    @owner.update!(visibility: "private")
    sign_in(moderator)
    moderator.update!(banned_at: Time.current)

    get brother_path(locale: :en, token: @owner.token)

    assert_response :not_found
    assert_nil session[:player_id]
  end

  test "in French: the fallback title, the French labels and plurals" do
    season = publish_sets_draft
    @owner.update_columns(persona_name: nil, created_at: Time.zone.local(2026, 3, 2, 12))
    code = Accounts::PublicProfile.code(@owner.token)

    get brother_path(locale: :fr, token: @owner.token)

    assert_select "title", "Joueur #{code}"
    assert_select "h1", "Joueur #{code}"
    assert_select ".profile-band__since", "Membre depuis mars 2026"
    assert_equal [ [ "Cartes", "0/#{card_total(season)}" ], [ "Sets complets", "0" ], [ "Succès", "0/10" ] ], keys
    assert_select "section.profile-stats[aria-label=Statistiques]"
    assert_equal [ "Raretés", "Activité" ], css_select(".profile-stats__kicker").map(&:text)
    assert_equal [ "Capsules ouvertes", "Premières découvertes", "Échanges conclus" ],
      figures(".profile-stats__grid:not(.profile-stats__grid--rarities)").map(&:first)
    assert_equal [ "Succès", "Sets" ], css_select("h2").map(&:text)
    assert_select "#profile-achievements-heading ~ .achievements__head .visually-hidden", "0 succès obtenu sur 10"
    assert_select ".profile-section__aside", "0 set entamé"

    set_members(season, "pirates").each { |id| hold(@owner, id, 1) }
    unlock("first_booster", 1.day.ago)
    get brother_path(locale: :fr, token: @owner.token)
    assert_equal "1", key("Sets complets")
    assert_select ".profile-section__label", "Derniers obtenus"
    assert_select ".profile-section__aside", "2 sets entamés"
    assert_select ".profile-sets .set-row .visually-hidden", "Pirates, thème, 8 cartes sur 8, complet"

    get brother_set_path(locale: :fr, token: @owner.token, kind: "theme", key: "pirates")
    assert_select "h1", "Pirates · Joueur #{code}"
    assert_select "title", "Pirates · Joueur #{code} · gameble"
    assert_select ".set-album__stamp", "Complet"

    get brother_path(locale: :en, token: @owner.token)
    assert_select "h1", "Player #{code}"
    assert_select ".profile-band__since", "Member since March 2026"
    assert_select ".profile-section__aside", "2 sets started"
  end

  [ "\u200B", "\u202E\u2066", "\u3164", "\u3000 \u2800" ].each do |name|
    test "a stored persona name of #{name.inspect}, nothing visible, falls back to Player <code>" do
      publish_sets_draft
      @owner.update_columns(persona_name: name)
      code = Accounts::PublicProfile.code(@owner.token)

      get brother_path(locale: :en, token: @owner.token)

      assert_select "title", "Player #{code}"
      assert_select "h1", "Player #{code}"
    end
  end

  test "a stored persona name is shown cleaned of its invisible characters" do
    publish_sets_draft
    @owner.update_columns(persona_name: "\u202EGa\u200Bbe\u3000the Brave")

    get brother_path(locale: :en, token: @owner.token)

    assert_select "h1", "Gabe the Brave"
    assert_no_match(/\u202E|\u200B/, response.body)
  end

  test "the persona name is escaped as user content" do
    publish_sets_draft
    @owner.update_columns(persona_name: "<b>Gabe</b> & co")

    get brother_path(locale: :en, token: @owner.token)

    assert_select "h1", "<b>Gabe</b> & co"
    assert_select "h1 b", false
    assert_select "title", "<b>Gabe</b> & co"
    assert_includes response.body, "&lt;b&gt;Gabe&lt;/b&gt; &amp; co"
  end

  test "no database id, no Steam id; the token only in URLs" do
    season = publish_sets_draft
    hold(@owner, set_members(season, "rpg").first, 2)
    ids = [ @owner.id ] + Catalog::Set.where(season_id: season.id).ids + Catalog::CardSeason.where(season_id: season.id).ids

    [ brother_path(locale: :en, token: @owner.token), brother_set_path(locale: :en, token: @owner.token, kind: "theme", key: "rpg") ].each do |path|
      get path

      assert_not_includes response.body, @owner.steam_id
      assert_select ".collection [data-id], .profile [data-id]", false
      without_urls = response.body.gsub(/(href|action|value)="[^"]*"/, "")
      assert_not_includes without_urls, @owner.token
      html = css_select("main").sole.to_html
      ids.each do |id|
        assert_no_match(/\b#{id}\b/, html.gsub(/<dd class="profile-figure__value">.*?<\/dd>|<p class="achievements__count"[^>]*>.*?<\/p>|\d+ \/ \d+|\d+ of \d+|\d+ cards?|\d+ sets?|\b(19|20)\d\d\b|×\d+|\d+ cop(y|ies)|seed-\d+-\d+|data-card-art-(width|height)-value="\d+"|width="\d+"|height="\d+"|\?page=\d+|page=\d+|\/seasons\/\d+|[Ss]eason \d+/, ""))
      end
    end
  end

  test "a visitor's profile costs nine queries whatever the owner's history, a signed-in viewer's five more" do
    season = publish_sets_draft
    set_members(season, "horror").last(2).each { |id| hold(@owner, id, 1) }
    unlock("first_booster", 1.day.ago)

    # Owner by token, published season; the summary, the season's card
    # count, the achievements earned, the rarities, the activity, the
    # owner's started sets and those sets.
    assert_request_queries(9) { get brother_path(locale: :en, token: @owner.token) }
    assert_response :success
    assert_select ".profile-sets .set-row", minimum: 1

    hold_started_sets(season)
    open_packs(season, 3)
    %w[first_epic first_trade boosters_10 first_repost].each { unlock(it, 1.hour.ago) }
    assert_request_queries(9) { get brother_path(locale: :en, token: @owner.token) }
    assert_select ".profile-sets .set-row", 5
    assert_select ".profile-achievements .achievement", 4

    sign_in(accounts_players(:moderator))
    # The same, the viewer's lookup and the top bar's three (reserve count,
    # next pack, copies per tier), and the tab bar's trades waiting.
    assert_request_queries(14) { get brother_path(locale: :en, token: @owner.token) }
    assert_response :success
  end

  test "the summary counts every edition: a game gone from the season, and a set completed through an earlier edition of a member" do
    season = publish_sets_draft
    pirates = set_members(season, "pirates")
    earlier = Catalog::CardSeason.insert_all!([ { card_id: Catalog::CardSeason.find(pirates.first).card_id, season_id: catalog_seasons(:one).id,
      prestige_score: 0.5, rating: 90, rarity: "rare", number: 900 } ], returning: :id).rows.flatten.sole
    hold(@owner, earlier, 1)
    pirates.drop(1).each { hold(@owner, it, 1) }
    hold(@owner, catalog_card_seasons(:portal_one).id, 2)

    get brother_path(locale: :en, token: @owner.token)

    assert_equal [ "#{pirates.size + 1}/#{card_total(season)}", "1" ], [ key("Cards"), key("Complete sets") ]
  end
end
