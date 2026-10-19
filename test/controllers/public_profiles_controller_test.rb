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

  def counts = css_select(".profile-summary__counts li").map(&:text)
  def album_count = css_select(".set-album__count").sole.text.squish

  # The rows of an entry section ("in-progress", "results") as
  # [ name, "owned/total", href ].
  def entry_rows(section)
    css_select("#set-entry-#{section}-title ~ .set-entry__list .set-row, #set-#{section}-title ~ .set-entry__list .set-row").map do |row|
      [ row.at_css(".set-row__name").text, row.at_css(".set-row__count").text, row["href"] ]
    end
  end

  test "a visitor sees the owner's name, their counts, then the search and their sets in progress, leading to the owner's sets" do
    season = publish_sets_draft
    pirates = set_members(season, "pirates")
    pirates.first(3).each { |id| hold(@owner, id, 1) }
    rpg = (set_members(season, "rpg") - pirates).first
    hold(@owner, rpg, 3)

    get brother_path(locale: :en, token: @owner.token)

    assert_response :success
    assert_select "title", "Gabe the Brave"
    assert_select "h1", "Gabe the Brave"
    assert_select "meta[name=robots][content=noindex]"
    assert_select "header.profile-summary.panel--brackets svg.profile-summary__avatar[aria-hidden=true]"
    assert_equal [ "4 cards collected", "0 sets complete" ], counts
    token = @owner.token
    in_progress = entry_rows("in-progress")
    assert_equal [ "Pirates", "3/8", "/en/brothers/#{token}/library/theme/pirates" ], in_progress.first
    assert_includes in_progress.map(&:first), "Horror"
    assert_not_includes in_progress.map(&:first), "RPG"
    assert_equal [ "Find a set", "In progress" ], css_select(".set-entry h2").map(&:text)
    assert_select "form.set-search__form[role=search][action='/en/brothers/#{token}']"
    assert_select ".set-search a", false
    assert_select ".set-entry__empty", false
    assert_select ".collection-kind, .collection-sets", false
    assert_select ".top-bar__start > a.button--secondary[href='/en']", "Bridge"
    assert_select "[style]", false
  end

  test "a set the owner completed earlier is counted and found by the search, marked complete" do
    season = publish_sets_draft
    set_members(season, "pirates").each { |id| hold(@owner, id, 1) }

    get brother_path(locale: :en, token: @owner.token, q: "pirates")

    assert_equal "1 set complete", counts.last
    assert_not_includes entry_rows("in-progress").map(&:first), "Pirates"
    assert_equal [ [ "Pirates", "8/8", "/en/brothers/#{@owner.token}/library/theme/pirates" ] ], entry_rows("results")
    assert_select "#set-results-title ~ .set-entry__list .set-tier--complete", "Complete"
    assert_select "#set-results-title ~ .set-entry__list .set-row .visually-hidden", "Pirates, theme, 8 cards out of 8, complete"
    assert_select ".set-search__status", "1 set found"
  end

  test "the owner's progress, never the viewer's" do
    season = publish_sets_draft
    set_members(season, "horror").first(2).each { |id| hold(@owner, id, 1) }
    viewer = accounts_players(:moderator)
    set_members(season, "rpg").first(5).each { |id| hold(viewer, id, 1) }
    sign_in(viewer)

    get brother_path(locale: :en, token: @owner.token, q: "rpg")
    assert_includes entry_rows("in-progress"), [ "Horror", "2/16", "/en/brothers/#{@owner.token}/library/theme/horror" ]
    assert_not_includes entry_rows("in-progress").map(&:first), "RPG"
    assert_equal [ [ "RPG", "#{(set_members(season, "rpg") & set_members(season, "horror").first(2)).size}/44",
      "/en/brothers/#{@owner.token}/library/theme/rpg" ] ], entry_rows("results")
    assert_equal "2 cards collected", counts.first

    get brother_set_path(locale: :en, token: @owner.token, kind: "theme", key: "rpg")
    assert_select ".set-album__grid .card", (set_members(season, "rpg") & set_members(season, "horror").first(2)).size
  end

  test "a player with no card: the search, a line pointing to it and no set, the counts at zero" do
    publish_sets_draft

    get brother_path(locale: :en, token: @owner.token)

    assert_response :success
    assert_select "#set-entry-in-progress-title", false
    assert_equal [ "Find a set" ], css_select(".set-entry h2").map(&:text)
    assert_select ".set-search ~ p.set-entry__empty", "No set in progress yet. Find one above."
    assert_select ".set-search a", false
    assert_select ".set-entry .set-row", false
    assert_equal [ "0 cards collected", "0 sets complete" ], counts
  end

  test "with no season published the profile says so and the counts are zero" do
    catalog_seasons(:one).update_columns(status: "draft", published_at: nil)

    get brother_path(locale: :en, token: @owner.token)

    assert_response :success
    assert_select ".profile__no-season", "No season of cards is published yet."
    assert_select ".set-entry", false
    assert_equal [ "0 cards collected", "0 sets complete" ], counts
  end

  test "a signed-out visitor opens an owner's album: the owner's faces and copies, read-only, under the set and the owner's names" do
    season = publish_sets_draft
    members = set_members(season, "horror")
    [ 0, 3, 7, 12, 15 ].each { hold(@owner, members[it], it == 3 ? 2 : 1, gained_at: 1.minute.ago) }

    get brother_set_path(locale: :en, token: @owner.token, kind: "theme", key: "horror")

    assert_response :success
    assert_select "title", "Horror · Gabe the Brave · gameble"
    assert_select "meta[name=robots][content=noindex]"
    assert_select "h1", 1
    assert_select "h1#set-album-heading[tabindex='-1']", "Horror · Gabe the Brave"
    assert_equal "5/16", album_count
    assert_equal "5 cards out of 16, silver tier", css_select("progress.set-album__bar").sole["aria-valuetext"]
    assert_equal [ "Bronze, 2 cards, reached", "Silver, 4 cards, reached", "Gold, 8 cards, not reached yet" ],
      css_select(".set-album__gauge .visually-hidden").map(&:text)
    assert_select ".set-album__grid .card.card--m", 5
    assert_select ".collection-grid--fill, .card--grid", false
    assert_equal [ "x2" ], css_select(".collection-slot__copies").map(&:text)
    assert_select ".missing-slot .visually-hidden", { count: 11, text: "Missing card" }
    assert_select ".collection-slot__new", false
    assert_select ".top-bar__end .collection-status, .top-bar__title", false
    assert_select ".profile-summary, .collection-kind, .collection-sets", false
    assert_select "[style]", false
    slugs = Catalog::CardSeason.where(id: members).includes(:card).index_by(&:id).transform_values { it.card.slug }
    assert_equal members.map { "/en/cards/#{slugs.fetch(it)}/seasons/#{season.number}" }, css_select(".set-album__grid > li > a.card-link").map { it["href"] }
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
    assert_equal "/fr/cards/#{older.card.slug}/seasons/1", slot.at_css("a.card-link")["href"]
    assert_equal "x3", slot.at_css(".collection-slot__copies").text
    assert_select ".set-album__gauge[aria-label=Paliers]"
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
    assert_select ".profile-summary__visibility", "Visible to your friends and the moderation team only"

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
      assert_select ".profile-summary__visibility", "Banned player: visible to the moderation team only"
      delete session_path(locale: :en)
    end

    sign_in(accounts_players(:moderator))
    Accounts::DeletePlayer.new.call(player: @owner).value!
    get brother_path(locale: :en, token: @owner.reload.token)
    assert_response :not_found
    assert_select "h1", "Profile not available"
  end

  test "staff read a public profile with its owner's visibility, without the banned line" do
    publish_sets_draft
    @owner.update!(visibility: "public")
    sign_in(accounts_players(:moderator))

    get brother_path(locale: :en, token: @owner.token)
    assert_response :success
    assert_select ".profile-summary__visibility", "Visible to everyone, even without an account"
    assert_no_match(/Banned player/, response.body)
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

  test "the summary states who may see the profile" do
    get brother_path(locale: :en, token: @owner.token)
    assert_select ".profile-summary__visibility", "Visible to everyone, even without an account"

    @owner.update!(visibility: "private")
    sign_in(@owner)
    get brother_path(locale: :fr, token: @owner.token)
    assert_select ".profile-summary__visibility", "Profil privé : vous seul et la modération le voyez"
  end

  test "in French, a staff member sees the banned line on a banned player's profile" do
    publish_sets_draft
    banned = accounts_players(:banned)
    banned.update_columns(persona_name: "Banned Brother")
    sign_in(accounts_players(:moderator))

    get brother_path(locale: :fr, token: banned.token)
    assert_response :success
    assert_select "h1", "Banned Brother"
    assert_select ".profile-summary__visibility", "Joueur banni : visible par la modération seulement"
  end

  test "in French: the fallback title, the French headings and plurals" do
    season = publish_sets_draft
    @owner.update_columns(persona_name: nil)
    hold(@owner, set_members(season, "pirates").first, 1)
    code = Accounts::PublicProfile.code(@owner.token)

    get brother_path(locale: :fr, token: @owner.token)

    assert_select "title", "Joueur #{code}"
    assert_select "h1", "Joueur #{code}"
    assert_equal [ "1 carte collectionnée", "0 collection complète" ], counts
    assert_equal [ "Chercher un set", "En cours" ], css_select(".set-entry h2").map(&:text)

    set_members(season, "pirates").drop(1).each { |id| hold(@owner, id, 1) }
    get brother_path(locale: :fr, token: @owner.token, q: "pirates")
    assert_equal "8 cartes collectionnées", counts.first
    assert_select "#set-results-title ~ .set-entry__list .set-row .visually-hidden", "Pirates, thème, 8 cartes sur 8, complet"

    get brother_set_path(locale: :fr, token: @owner.token, kind: "theme", key: "pirates")
    assert_select "h1", "Pirates · Joueur #{code}"
    assert_select "title", "Pirates · Joueur #{code} · gameble"
    assert_select ".set-album__stamp", "Complet"

    get brother_path(locale: :en, token: @owner.token)
    assert_select "h1", "Player #{code}"
    assert_equal "8 cards collected", counts.first
    assert_match(/\A1 set complete\z|\A\d+ sets complete\z/, counts.last)
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
        assert_no_match(/\b#{id}\b/, html.gsub(/\d+ \/ \d+|\d+ of \d+|\d+ cards?|\d+ sets?|\b(19|20)\d\d\b|×\d+|\d+ cop(y|ies)|seed-\d+-\d+|data-card-art-(width|height)-value="\d+"|width="\d+"|height="\d+"|\?page=\d+|page=\d+|\/seasons\/\d+|[Ss]eason \d+/, ""))
      end
    end
  end

  test "a visitor's profile costs five queries, a signed-in viewer's five more, a search two more" do
    season = publish_sets_draft
    hold(@owner, set_members(season, "pirates").first, 1)

    # Owner by token, published season, the owner's standings, the sets
    # shown, the summary.
    assert_request_queries(5) { get brother_path(locale: :en, token: @owner.token) }
    assert_response :success
    assert_select ".set-entry .set-row", minimum: 1

    sign_in(accounts_players(:moderator))
    # The same, the viewer's lookup and the top bar's three (reserve count,
    # next pack, copies per tier), and the tab bar's trades waiting.
    assert_request_queries(10) { get brother_path(locale: :en, token: @owner.token) }
    assert_response :success

    # The search's sets and the figures of those the owner has not started.
    assert_request_queries(12) { get brother_path(locale: :en, token: @owner.token, q: "o") }
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

    assert_equal [ "#{pirates.size + 1} cards collected", "1 set complete" ], counts
  end
end
