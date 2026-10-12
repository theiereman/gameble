require "test_helper"
require_relative "../support/catalog_seeds"
require_relative "../support/library_requests"

class PublicProfilesControllerTest < ActionDispatch::IntegrationTest
  include CatalogSeeds
  include LibraryRequests

  setup do
    OmniAuth.config.test_mode = true
    @owner = accounts_players(:player)
    @owner.update_columns(persona_name: "Gabe the Brave")
  end

  teardown do
    OmniAuth.config.mock_auth.delete(:steam)
    OmniAuth.config.test_mode = false
  end

  # The list of sets as [ name, "owned / total" ] pairs, in order.
  def spines
    css_select(".collection-sets__list .set-row").map { |row| [ row.at_css(".set-row__name").text, row.at_css(".set-row__count").text.sub("/", " / ") ] }
  end

  def set_rows = css_select(".collection-sets__list a.set-row")
  def open_tab = css_select(".collection-kind[aria-current=true]").sole.text
  def tabs = css_select(".collection-kind")
  def counts = css_select(".profile-summary__counts li").map(&:text)
  def heading = css_select(".profile-set__heading").sole.text
  def progress = css_select(".profile-set__progress [aria-hidden]").sole.text

  # The keys of the published season's sets of every kind, in shelf order.
  def every_kind(season) = Catalog::SeasonShelf.every_kind(season:).map(&:key)

  def label(season, key) = SetLabel.for(Catalog::Set.find_by!(season_id: season.id, key:))

  test "a visitor sees the owner's name, their counts and the sets they have started first" do
    season = publish_sets_draft
    pirates = set_members(season, "pirates")
    pirates.each { |id| hold(@owner, id, 1) }
    rpg = (set_members(season, "rpg") - pirates).first
    hold(@owner, rpg, 3)

    get brother_path(locale: :en, token: @owner.token)

    assert_response :success
    assert_select "title", "Gabe the Brave"
    assert_select "h1", "Gabe the Brave"
    assert_select "meta[name=robots][content=noindex]"
    # The summary: the avatar, the name, the counts; no tome shelf.
    assert_select "header.profile-summary.panel--brackets svg.profile-summary__avatar[aria-hidden=true]"
    assert_select ".library, .shelf, .tome, .library__room", false
    held = pirates + [ rpg ]
    started = every_kind(season).select { |key| (set_members(season, key) & held).any? }
    complete = every_kind(season).count { |key| (set_members(season, key) - held).empty? }
    assert_equal [ "9 cards collected", I18n.t("public_profiles.show.complete_sets", count: complete, locale: :en) ], counts
    assert_equal "Started", open_tab
    assert_equal [ "Started", "Themes", "UFOs" ], tabs.map(&:text)
    assert_equal started.map { |key| [ label(season, key), "#{(set_members(season, key) & held).size} / #{set_members(season, key).size}" ] }, spines
    assert_includes spines, [ "Pirates", "8 / 8" ]
    assert_select ".top-bar__start > a.button--secondary[href='/en']", "Bridge"
    assert_select "a.library__profile", false
    assert_select ".collection .collection__aside .collection-sets"
    assert_select ".profile__hint", "Pick a set to see the cards it holds."
  end

  test "a fully owned set is labelled complete and counted; the others are not" do
    season = publish_sets_draft
    set_members(season, "pirates").each { |id| hold(@owner, id, 1) }

    get brother_path(locale: :en, token: @owner.token, kind: "theme")

    assert_equal "Themes", open_tab
    assert_select ".set-row", 4
    assert_select ".set-row .set-row__count--complete", 1
    assert_select ".set-row .visually-hidden", /8 cards owned out of 8 · Complete/
    assert_equal [ "Pirates" ], set_rows.select { it.at_css(".set-row__count--complete") }.map { it.at_css(".set-row__name").text }

    get brother_path(locale: :en, token: @owner.token)
    complete = set_rows.select { it.at_css(".set-row__count--complete") }.map { it.at_css(".set-row__name").text }
    assert_includes complete, "Pirates"
    partial = spines.reject { |_, count| count.split(" / ").uniq.size == 1 }
    assert partial.any?
    assert_equal spines.size - partial.size, complete.size
    assert_match(/\A#{complete.size} sets? complete\z/, counts.last)
  end

  test "each tab shows its kind with the owner's progress, and leads to its sets" do
    season = publish_sets_draft
    first = set_members(season, "horror").first
    hold(@owner, first, 2)

    get brother_path(locale: :en, token: @owner.token, kind: "theme")
    assert_equal "Themes", open_tab
    assert_equal [ [ "Horror", "1 / 16" ], [ "Pirates", "#{set_members(season, "pirates").include?(first) ? 1 : 0} / 8" ], [ "Roguelike", "0 / 119" ],
      [ "RPG", "0 / 44" ] ], spines
    token = @owner.token
    assert_equal [ "/en/brothers/#{token}", "/en/brothers/#{token}?kind=theme", "/en/brothers/#{token}?kind=ufo" ], tabs.map { it["href"] }
    assert_equal "/en/brothers/#{token}/library/theme/horror?page=1", set_rows.first["href"]
    assert_select ".collection-kind[data-turbo-prefetch=false]", 3
    assert_select ".collection-sets__list a.set-row[data-turbo-prefetch=false]", 4

    get brother_path(locale: :en, token: @owner.token, kind: "ufo")
    assert_equal "UFOs", open_tab
    assert_equal [ [ "The UFOs", "0 / 15" ] ], spines

    get brother_path(locale: :en, token: @owner.token)
    assert_equal "Started", open_tab
    assert set_rows.all? { it["href"].end_with?("?page=1&tab=started") }
  end

  test "a shelf of more than fifty sets pages, its page links unprefetched" do
    seed_published_sets((1..60).map { |volume| [ "tome", "action-#{volume}", { "genre" => "action", "volume" => volume, "volumes" => 60 } ] })

    get brother_path(locale: :en, token: @owner.token, kind: "tome")

    assert_select ".collection-sets__list .set-row", 50
    assert_select ".series-nav a[href=?][data-turbo-prefetch=false]", "/en/brothers/#{@owner.token}?kind=tome&page=2", minimum: 1
    assert_select ".series-nav a[href]:not([data-turbo-prefetch=false])", false
  end

  [ nil, "", "nope", [ "theme" ], "publisher", "started" ].each do |kind|
    test "a kind of #{kind.inspect} opens the Started tab" do
      publish_sets_draft

      get brother_path(locale: :en, token: @owner.token), params: { kind: }.compact

      assert_response :success
      assert_equal "Started", open_tab
    end
  end

  test "the owner's progress, never the viewer's" do
    season = publish_sets_draft
    hold(@owner, set_members(season, "horror").first, 1)
    viewer = accounts_players(:moderator)
    set_members(season, "rpg").first(5).each { |id| hold(viewer, id, 1) }
    sign_in(viewer)

    get brother_path(locale: :en, token: @owner.token, kind: "theme")
    assert_includes spines, [ "RPG", "0 / 44" ]
    assert_includes spines, [ "Horror", "1 / 16" ]
    assert_equal "1 card collected", counts.first

    get brother_set_path(locale: :en, token: @owner.token, kind: "theme", key: "rpg")
    assert_select ".collection-grid .card", 0
  end

  test "a player with no card: the Started shelf says so and the counts are zero" do
    publish_sets_draft

    get brother_path(locale: :en, token: @owner.token)

    assert_response :success
    assert_select ".collection-sets__list .set-row", false
    assert_select ".collection-sets__empty", "No set started yet: this collection still awaits its first card."
    assert_select ".profile__hint", false
    assert_equal [ "0 cards collected", "0 sets complete" ], counts
  end

  test "with no season published the shelf says so and the counts are zero" do
    catalog_seasons(:one).update_columns(status: "draft", published_at: nil)

    get brother_path(locale: :en, token: @owner.token)

    assert_response :success
    assert_select ".collection-sets__empty", "No season of cards is published yet."
    assert_select ".collection-kind", false
    assert_equal [ "0 cards collected", "0 sets complete" ], counts
  end

  test "a set of the profile shows the owner's cards and copies, the rest as empty slots" do
    season = publish_sets_draft
    members = set_members(season, "horror")
    hold(@owner, members[0], 1)
    hold(@owner, members[3], 2)

    get brother_set_path(locale: :en, token: @owner.token, kind: "theme", key: "horror", page: 1)

    assert_response :success
    assert_select "title", "Gabe the Brave"
    assert_select "meta[name=robots][content=noindex]"
    assert_equal "Horror", heading
    assert_equal "2 / 16", progress
    assert_select ".collection-grid .card.card--m", 2
    # The owner's copies from x1, as in the collection; no NOUVEAU tag.
    assert_equal [ "x1", "x2" ], css_select(".collection-slot__copies").map(&:text)
    assert_select ".collection-slot__new", false
    assert_select ".missing-slot .visually-hidden", { count: 14, text: "Missing card" }
    assert_select ".missing-slot svg.missing-slot__icon"
    assert_select "a.profile__owner[href=?]", "/en/brothers/#{@owner.token}?kind=theme&page=1", "The collection of Gabe the Brave"
    assert_select ".collection__aside .collection-kind[aria-current=true]", "Themes"
    assert_select ".collection__aside .set-row[aria-current=page] .set-row__name", "Horror"
    assert_select ".profile-summary", false
    assert_select ".library, .open-tome, .tome, .slot", false
    assert_select ".collection-grid > li > a.card-link[data-turbo-prefetch=false]", 16
    # The owner's faces are named by their label; an empty slot by its
    # visible text, whoever looks.
    links = css_select(".collection-grid > li > a.card-link")
    face, missing = Catalog::CardViews.call(members, locale: :en).values_at(members[3], members[1])
    assert_equal "#{face.title}, #{I18n.t("catalog.rarity.#{face.rarity}", locale: :en)}, season #{season.number}", links[3]["aria-label"]
    assert_equal members.map { |id| id.in?([ members[0], members[3] ]) }, links.map { it["aria-label"].present? }
    assert_equal "#{missing.title} #{missing.year} Missing card", links[1].text.squish
  end

  test "a face of a profile set leads to the card's own page, which an older browser opens, and its sets to the library" do
    season = publish_sets_draft
    members = set_members(season, "pirates")
    hold(@owner, members.first, 1)
    view = Catalog::CardViews.call([ members.first ], locale: :en).fetch(members.first)
    old = { "User-Agent" => "Mozilla/5.0 (iPhone; CPU iPhone OS 16_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.6 Mobile/15E148 Safari/604.1" }

    get brother_set_path(locale: :en, token: @owner.token, kind: "theme", key: "pirates", page: 1), headers: old
    assert_response :success
    href = css_select(".collection-grid > li > a.card-link").first["href"]
    assert_equal "/en/cards/#{view.id}/seasons/#{season.number}", href

    get href, headers: old
    assert_response :success
    assert_select ".public-card h1", view.title
    assert_not_includes response.body, "Gabe the Brave"
    # The public page lists no sets: the library its sets lead to stays open.
    set_link = library_set_path(locale: :en, kind: "theme", key: "pirates")
    assert_equal "/en/library/theme/pirates", set_link

    get set_link, headers: old
    assert_response :success
    assert_select ".set-row[aria-current=page] .set-row__name", "Pirates"

    get home_path(locale: :en), headers: old
    assert_response :not_acceptable
  end

  test "a set opened from the Started shelf keeps the Started shelf beside it" do
    season = publish_sets_draft
    hold(@owner, set_members(season, "pirates").first, 1)

    get brother_path(locale: :en, token: @owner.token)
    href = set_rows.find { it.at_css(".set-row__name").text == "Pirates" }["href"]
    assert_equal "/en/brothers/#{@owner.token}/library/theme/pirates?page=1&tab=started", href

    get href
    assert_response :success
    assert_equal "Pirates", heading
    assert_select ".collection__aside .collection-kind[aria-current=true]", "Started"
    assert_select ".collection__aside .set-row[aria-current=page] .set-row__name", "Pirates"
    assert_select "a.profile__owner[href=?]", "/en/brothers/#{@owner.token}?page=1"
    assert css_select(".collection__aside a.set-row").all? { it["href"].end_with?("&tab=started") }
  end

  test "a wrong kind, an unknown key or a key of another kind is not found under a profile" do
    publish_sets_draft

    get "/en/brothers/#{@owner.token}/library/nope/rpg"
    assert_response :not_found

    get brother_set_path(locale: :en, token: @owner.token, kind: "theme", key: "action")
    assert_response :not_found

    get brother_set_path(locale: :en, token: @owner.token, kind: "publisher", key: "rpg")
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
    assert_select ".profile-summary__visibility", "Visible to your friends and the Brotherhood's officers only"

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
      assert_select ".profile-summary__visibility", "Banned player: visible to the Brotherhood's officers only"

      @owner.update!(visibility: "public")
      get brother_path(locale: :en, token: @owner.token)
      assert_response :success, role
      assert_select ".profile-summary__visibility", "Visible to everyone, even without an account"
      assert_no_match(/Banned player/, response.body, role)
      delete session_path(locale: :en)
    end

    sign_in(accounts_players(:moderator))
    Accounts::DeletePlayer.new.call(player: @owner).value!
    get brother_path(locale: :en, token: @owner.reload.token)
    assert_response :not_found
    assert_select "h1", "Profile not available"
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
    assert_select ".profile-summary__visibility", "Profil privé : vous seul et les officiers de la Confrérie le voyez"
  end

  test "in French, a staff member sees the banned line on a banned player's profile" do
    publish_sets_draft
    banned = accounts_players(:banned)
    banned.update_columns(persona_name: "Banned Brother")
    sign_in(accounts_players(:moderator))

    get brother_path(locale: :fr, token: banned.token)
    assert_response :success
    assert_select "h1", "Banned Brother"
    assert_select ".profile-summary__visibility", "Joueur banni : visible des officiers de la Confrérie seulement"
  end

  test "in French: the fallback title, the French tabs and plurals" do
    season = publish_sets_draft
    @owner.update_columns(persona_name: nil)
    hold(@owner, set_members(season, "pirates").first, 1)
    code = Accounts::PublicProfile.code(@owner.token)

    get brother_path(locale: :fr, token: @owner.token)

    assert_select "title", "Joueur #{code}"
    assert_select "h1", "Joueur #{code}"
    assert_equal "Entamées", open_tab
    assert_equal [ "1 carte collectionnée", "0 collection complète" ], counts
    assert_equal [ "Entamées", "Thèmes", "OVNI" ], tabs.map(&:text)

    set_members(season, "pirates").drop(1).each { |id| hold(@owner, id, 1) }
    get brother_path(locale: :fr, token: @owner.token, kind: "theme")
    assert_equal "8 cartes collectionnées", counts.first
    assert_select ".set-row .visually-hidden", /8 cartes possédées sur 8 · Complet/

    get brother_path(locale: :en, token: @owner.token)
    assert_select "h1", "Player #{code}"
    assert_equal "8 cards collected", counts.first
    assert_match(/\A1 set complete\z|\A\d+ sets complete\z/, counts.last)

    get brother_set_path(locale: :fr, token: @owner.token, kind: "theme", key: "pirates")
    assert_select "a.profile__owner", "La collection de Joueur #{code}"
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
        assert_no_match(/\b#{id}\b/, html.gsub(/Tome \d+|\d+ \/ \d+|\d+ of \d+|\d+ cards?|\d+ sets?|\b(19|20)\d\d\b|×\d+|\d+ cop(y|ies)|seed-\d+-\d+|data-card-art-(width|height)-value="\d+"|width="\d+"|height="\d+"|\?page=\d+|page=\d+|\/seasons\/\d+|[Ss]eason \d+/, ""))
      end
    end
  end

  test "a visitor's profile costs eight queries, a signed-in viewer's five more" do
    season = publish_sets_draft
    hold(@owner, set_members(season, "pirates").first, 1)

    # Owner by token, published season, the kinds the season holds, shelf
    # count, shelf page, totals, progress, summary.
    assert_request_queries(8) { get brother_path(locale: :en, token: @owner.token) }
    assert_response :success
    assert_select ".collection-sets__list .set-row", minimum: 1

    sign_in(accounts_players(:moderator))
    # The same, the viewer's lookup and the top bar's three (reserve count,
    # next pack, copies per tier), and the tab bar's trades waiting.
    assert_request_queries(13) { get brother_path(locale: :en, token: @owner.token) }
    assert_response :success
  end

  test "a visitor's profile set costs ten queries, a signed-in viewer's five more" do
    season = publish_sets_draft
    hold(@owner, set_members(season, "rpg").first, 1)

    # Owner by token, published season, set slots, card views, the owner's
    # quantities, the kinds the season holds, shelf count, shelf page,
    # totals, the owner's progress.
    assert_request_queries(10) { get brother_set_path(locale: :en, token: @owner.token, kind: "theme", key: "rpg") }
    assert_response :success

    sign_in(accounts_players(:moderator))
    # The same, the viewer's lookup, the top bar's three and the trades
    # waiting.
    assert_request_queries(15) { get brother_set_path(locale: :en, token: @owner.token, kind: "theme", key: "rpg", tab: "started") }
    assert_response :success
  end
end
