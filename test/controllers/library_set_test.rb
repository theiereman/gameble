require "test_helper"
require_relative "../support/catalog_seeds"
require_relative "../support/game_sets"
require_relative "../support/library_requests"
require_relative "../support/steam_sign_in"

class LibrarySetTest < ActionDispatch::IntegrationTest
  include CatalogSeeds
  include GameSets
  include LibraryRequests
  include SteamSignIn

  def title(card_season_id, locale = "en")
    Catalog::CardText.find_by!(card_id: Catalog::CardSeason.find(card_season_id).card_id, locale:).title
  end

  def year(card_season_id) = Catalog::CardSeason.find(card_season_id).card.release_date.year

  def slug(card_season_id) = Catalog::CardSeason.find(card_season_id).card.slug

  def slots
    css_select(".set-album__grid > li").map do |slot|
      if (card = slot.at_css(".card"))
        [ :owned, card.at_css(".card__title").text, slot.at_css(".collection-slot__copies")&.text ]
      else
        [ :missing, slot.at_css(".missing-slot__title").text, slot.at_css(".missing-slot__year").text.to_i ]
      end
    end
  end

  def value_text = css_select("progress.set-album__bar").sole["aria-valuetext"]

  # The album's ticks as [ tier, reached, place on the bar, figure under it ].
  def album_ticks
    ticks = css_select(".set-album__ticks .set-row__tick")
    figures = css_select(".set-album__ticks .set-album__figure")
    assert_equal ticks.size, figures.size
    ticks.zip(figures).map do |tick, figure|
      assert_equal tick["data-tier-at"], figure["data-tier-at"]
      assert_equal tick.classes.include?("is-reached"), figure.classes.include?("is-reached")
      [ tick["class"][/--(\w+)/, 1], tick.classes.include?("is-reached"), tick["data-tier-at"], figure.text ]
    end
  end
  def count = css_select(".set-album__count").sole.text.squish
  def title_line = css_select(".set-album__title *").filter_map { it["class"]&.split&.first }

  def earlier_edition(card_season_id, rarity:)
    member = Catalog::CardSeason.find(card_season_id)
    Catalog::CardSeason.insert_all!([ { card_id: member.card_id, season_id: catalog_seasons(:one).id, prestige_score: 0.5, rating: 80.0,
      rarity: Catalog::Rarity::TIERS.key(rarity), number: 900 } ], returning: :id).rows.flatten.sole
  end

  test "a theme at expert: its name and count on one line, its value text, its rank ticks, its faces in set order and the missing slots naming their games" do
    season = publish_sets_draft
    player = accounts_players(:player)
    members = set_members(season, "horror")
    held = [ 0, 3, 7, 12, 14, 15 ]
    held.each { hold(player, members[it], it == 3 ? 2 : 1) }
    sign_in(player)

    get library_set_path(locale: :en, kind: "theme", key: "horror")

    assert_response :success
    assert_select "title", "Horror · Collection · gameble"
    assert_select "h1", 1
    assert_select "h1#set-album-heading.set-album__name[tabindex='-1'][data-set-album-target=heading]", "Horror"
    assert_select "header.set-album__header.panel--brackets"
    assert_select "p.top-bar__title", "Collection"
    assert_select "header.top-bar[data-screen-label=Set] .top-bar__start.top-bar__start--phone-previous > a.top-bar__previous[data-controller=previous-screen]"
    assert_select ".collection-status__value", "6 / 150"
    assert_select ".set-album__kind, .set-album__facts, .set-album__gauge", false
    assert_equal [ "set-album__name", "set-album__count" ], title_line
    assert_equal "6/16", count
    assert_select ".set-album__count[aria-hidden=true]"
    assert_select "progress.set-album__bar[aria-labelledby=set-album-heading][value='6'][max='16']"
    assert_equal "6 cards out of 16, expert tier", value_text
    assert_select ".set-album[data-controller=set-album] .set-album__track[data-controller=tier-ticks] .set-album__ticks[aria-hidden=true]"
    assert_equal [ [ "expert", true, "0.375", "6" ], [ "master", false, "0.6875", "11" ] ], album_ticks
    assert_select "header.set-album__header.set-album__header--tiered"
    assert_select ".set-album__stamp", false
    expected = members.each_with_index.map do |id, index|
      if held.include?(index) then [ :owned, title(id), (index == 3 ? "x2" : nil) ] else [ :missing, title(id), year(id) ] end
    end
    assert_equal expected, slots
    assert_select ".missing-slot .visually-hidden", { count: 10, text: "Missing card" }
    assert_select ".collection-slot .visually-hidden", "2 copies"
    assert_select ".collection-slot .visually-hidden", "1 copy"
    assert_select "ol.set-album__grid.collection-grid--fill[aria-label='Cards in the set'][data-controller=grid-keys]"
    assert_select ".set-album__grid .card.card--grid", 6
    assert_select ".card--m", false
    assert_select ".set-album[data-controller=set-album]"
    assert_select ".collection-pages", false
    assert_select "[style]", false
    links = css_select(".set-album__grid > li > a.card-link")
    context = { set_key: "horror", set_kind: "theme" }.to_query
    assert_equal members.map { "/en/cards/#{slug(it)}/seasons/#{season.number}?#{context}" }, links.map { it["href"] }
    assert_equal members.each_index.map { held.include?(it) }, links.map { it["aria-label"].present? }
  end

  test "a completed franchise shows the stamp after its name and no ticks, in French" do
    season = publish_franchises_and_studios_draft
    player = accounts_players(:player)
    set_members(season, "tom-clancy").each { hold(player, it, 1) }
    sign_in(player)

    get library_set_path(locale: :fr, kind: "franchise", key: "tom-clancy")

    assert_response :success
    assert_select "title", "Tom Clancy · Collection · gameble"
    assert_select "h1", "Tom Clancy"
    assert_select ".set-album__title .set-album__stamp", "Complet"
    assert_equal [ "set-album__name", "set-album__stamp", "set-album__count" ], title_line
    assert_select ".set-album__kind", false
    assert_equal "3/3", count
    assert_equal "3 cartes sur 3, complet", value_text
    assert_select ".set-album__gauge, .set-album__ticks, .set-row__tick", false
    assert_select ".set-album__grid .card.card--grid", 3
    assert_select ".collection-slot__copies", false
    assert_select ".collection-slot .visually-hidden", { count: 3, text: "1 exemplaire" }
  end

  test "in French a theme's value text names its tier in French" do
    season = publish_sets_draft
    player = accounts_players(:player)
    set_members(season, "horror").first(8).each { hold(player, it, 1) }
    sign_in(player)

    get library_set_path(locale: :fr, kind: "theme", key: "horror")

    assert_equal "8 cartes sur 16, palier expert", value_text
    assert_equal [ "6", "11" ], css_select(".set-album__figure").map(&:text)
    assert_select ".set-album__gauge", false
    assert_select "ol.set-album__grid[aria-label='Cartes du set']"
    assert_select ".missing-slot .visually-hidden", { count: 8, text: "Carte manquante" }

    delete session_path(locale: :fr)
    sign_in(accounts_players(:moderator))
    get library_set_path(locale: :fr, kind: "theme", key: "pirates")
    assert_equal "0 carte sur 8", value_text
  end

  test "a game held only in an earlier season fills its slot with that edition, leading to the set's card within the set" do
    season = publish_sets_draft
    player = accounts_players(:player)
    members = set_members(season, "horror")
    earlier = earlier_edition(members[2], rarity: :rare)
    hold(player, earlier, 1)
    sign_in(player)

    get library_set_path(locale: :en, kind: "theme", key: "horror")

    assert_equal "1/16", count
    slot = css_select(".set-album__grid > li")[2]
    link = slot.at_css("a.card-link")
    assert_equal "/en/cards/#{slug(members[2])}/seasons/#{season.number}?set_key=horror&set_kind=theme", link["href"]
    assert_equal "#{title(members[2])}, #{year(members[2])}, Rare, season 1", link["aria-label"]
    assert_nil slot.at_css(".collection-slot__copies")
    assert_equal "1 copy", slot.css(".visually-hidden").map(&:text).find { it.include?("cop") }
  end

  test "a game held in two editions shows the best one and counts the copies of both" do
    season = publish_sets_draft
    player = accounts_players(:player)
    members = set_members(season, "horror")
    Catalog::CardSeason.where(id: members[4]).update_all(rarity: Catalog::Rarity::TIERS.key(:epic))
    hold(player, earlier_edition(members[4], rarity: :rare), 1)
    hold(player, members[4], 2)
    sign_in(player)

    get library_set_path(locale: :en, kind: "theme", key: "horror")

    slot = css_select(".set-album__grid > li")[4]
    assert_equal "x3", slot.at_css(".collection-slot__copies").text
    assert_equal "/en/cards/#{slug(members[4])}/seasons/#{season.number}?#{{ set_key: "horror", set_kind: "theme" }.to_query}", slot.at_css("a.card-link")["href"]
    view = Catalog::CardViews.call([ members[4] ], locale: :en).fetch(members[4])
    assert_equal "#{view.title}, #{view.year}, Epic, season #{season.number}", slot.at_css("a.card-link")["aria-label"]
    assert_equal "1/16", count
  end

  test "new cards carry the New tag on the viewer's album; the album moves no watermark" do
    season = publish_sets_draft
    player = accounts_players(:player)
    members = set_members(season, "horror")
    Game::PlayerState.find_by!(player_id: player.id).update_columns(collection_seen_up_to: 1.hour.ago)
    hold(player, members[0], 1, gained_at: 1.minute.ago)
    hold(player, earlier_edition(members[1], rarity: :rare), 1, gained_at: 1.minute.ago)
    hold(player, members[2], 1, gained_at: 2.hours.ago)
    sign_in(player)

    assert_no_changes -> { Game::PlayerState.find_by!(player_id: player.id).attributes } do
      get library_set_path(locale: :en, kind: "theme", key: "horror")
    end

    assert_equal [ true, true, false ], css_select(".set-album__grid > li").first(3).map { it.at_css(".collection-slot__new").present? }
    assert_select ".collection-slot__new", { count: 2, text: "New" }
    assert_select "[data-controller=collection-seen]", false
  end

  test "a visitor is sent to the landing, an unknown set too" do
    publish_sets_draft

    get library_set_path(locale: :fr, kind: "theme", key: "horror")
    assert_redirected_to home_path(locale: :fr)
    assert_response :see_other
    assert_nil flash[:alert]

    get library_set_path(locale: :en, kind: "theme", key: "nope")
    assert_redirected_to home_path(locale: :en)
  end

  test "a ranked theme's value text names its rank: 31 cards out of 62, expert tier" do
    season, cards = published_cards(62)
    insert_ranked_theme(cards, key: "roguelike", season:)
    player = accounts_players(:player)
    hold_all(player, cards.first(31))
    sign_in(player)

    get library_set_path(locale: :en, kind: "theme", key: "roguelike")

    assert_equal "31 cards out of 62, expert tier", value_text
    assert_equal [ [ "apprentice", true, "0.1129", "7" ], [ "adept", true, "0.2581", "16" ], [ "expert", true, "0.5", "31" ], [ "master", false, "0.7581", "47" ] ],
      album_ticks

    get library_set_path(locale: :fr, kind: "theme", key: "roguelike")
    assert_equal "31 cartes sur 62, palier expert", value_text
  end

  test "a ranked theme of 40 cards: three rank ticks, each with its mark and its figure, the reached ones lit; complete, no ticks" do
    season, cards = published_cards(40)
    insert_ranked_theme(cards, key: "roguelike", season:)
    player = accounts_players(:player)
    hold_all(player, cards.first(22))
    sign_in(player)

    get library_set_path(locale: :en, kind: "theme", key: "roguelike")

    assert_equal "22 cards out of 40, expert tier", value_text
    assert_equal [ [ "adept", true, "0.25", "10" ], [ "expert", true, "0.5", "20" ], [ "master", false, "0.75", "30" ] ], album_ticks
    assert_equal %w[adept expert master], css_select(".set-album__ticks .set-row__tick > .set-row__tick-mark > svg.rank-mark.rank-mark--fine").map { it["class"][/rank-mark--(?!fine)(\w+)/, 1] }
    assert_select ".set-album__ticks .set-notches", false
    assert_select "header.set-album__header--tiered:not(.set-album__header--complete)"
    assert_select "[style]", false

    hold_all(player, cards.drop(22))
    get library_set_path(locale: :en, kind: "theme", key: "roguelike")

    assert_equal "40 cards out of 40, complete", value_text
    assert_select "header.set-album__header.set-album__header--complete:not(.set-album__header--tiered)"
    assert_select ".set-album__ticks, .set-row__tick, .set-album__figure", false
  end

  test "an earlier season's metal theme of 3 cards has completion alone: no ticks and no metal on its row or its album" do
    season, cards = published_cards(3)
    insert_theme(cards, key: "roguelike", season:)
    player = accounts_players(:player)
    hold_all(player, cards.first(2))
    sign_in(player)

    get library_path(locale: :en)

    row = css_select(".set-entry .set-row").sole
    assert_empty row.css(".set-tier")
    assert_not row.classes.include?("set-row--tiered")
    assert_empty row.css(".set-row__tick")

    get library_set_path(locale: :en, kind: "theme", key: "roguelike")

    assert_equal "2 cards out of 3", value_text
    assert_select "header.set-album__header--tiered", false
    assert_select ".set-album__ticks, .set-row__tick, .set-album__figure", false
  end

  test "an earlier season's metal theme shows its three ticks, the reached ones raised, and names its metal" do
    season, cards = published_cards(62)
    insert_theme(cards, key: "roguelike", season:)
    player = accounts_players(:player)
    hold_all(player, cards.first(16))
    sign_in(player)

    get library_set_path(locale: :en, kind: "theme", key: "roguelike")

    assert_equal "16 cards out of 62, silver tier", value_text
    assert_select ".set-album__ticks[aria-hidden=true] .set-row__tick", 3
    assert_select ".set-album__ticks .set-row__tick.is-reached", 2
    assert_select ".set-album__ticks .set-row__tick--gold.is-reached", false
    assert_equal [ [ "bronze", true, "0.1129", "7" ], [ "silver", true, "0.2581", "16" ], [ "gold", false, "0.5", "31" ] ], album_ticks
    assert_equal [ 1, 2, 3 ], css_select(".set-album__ticks .set-row__tick").map { it.css(".set-row__tick-mark .set-notches i").size }
    assert_select ".set-album__ticks .rank-mark", false
    assert_select "[style]", false
  end

  test "a set of more than sixty cards is paged sixty to a page" do
    season, cards = published_cards(130)
    insert_theme(cards, key: "roguelike", season:)
    sign_in(accounts_players(:player))

    get library_set_path(locale: :en, kind: "theme", key: "roguelike")
    assert_equal cards.first(60).map { title(it) }, slots.map(&:second)
    assert_select ".collection-pages a[rel=next][href=?]", "/en/library/theme/roguelike?page=2"

    get library_set_path(locale: :en, kind: "theme", key: "roguelike", page: 3)
    assert_equal cards.last(10).map { title(it) }, slots.map(&:second)
    assert_select ".collection-pages a[rel=prev][href=?]", "/en/library/theme/roguelike?page=2"

    get library_set_path(locale: :fr, kind: "theme", key: "roguelike", page: 4)
    assert_empty slots
    assert_select ".collection-grid__empty", "Plus aucune carte ici : la grille s'arrête sur une page précédente. Revenez à la dernière page."
    assert_select ".collection-pages a[rel=prev][href=?]", "/fr/library/theme/roguelike?page=3"
  end

  test "an album of 752 cards costs the same queries as one of three: ten for a player" do
    season, cards = published_cards(755)
    insert_theme(cards.first(752), key: "roguelike", season:)
    insert_theme(cards.last(3), key: "horror", season:)
    player = accounts_players(:player)
    hold_all(player, cards.first(400) + cards.last(1))
    sign_in(player)

    # Player lookup, published season; the album: its set, members and
    # tiers, the player's editions, the page's card views; the top bar's
    # unique cards and season's cards; the tab bar's trades waiting.
    assert_request_queries(10) { get library_set_path(locale: :en, kind: "theme", key: "roguelike") }
    assert_response :success
    assert_select ".set-album__grid > li", 60
    assert_select ".collection-pages"
    assert_equal "400/752", count

    assert_request_queries(10) { get library_set_path(locale: :en, kind: "theme", key: "horror") }
    assert_equal "1/3", count
  end

  test "every kind opens its album under its name" do
    season = publish_sets_draft
    sign_in(accounts_players(:player))
    get library_set_path(locale: :en, kind: "ufo", key: "ufos")
    assert_select "h1", "The UFOs"
    assert_select ".set-album__kind", false
    assert_equal set_members(season, "ufos").map { title(it) }, slots.map(&:second)

    publish_franchises_and_studios_draft
    get library_set_path(locale: :fr, kind: "studio", key: "capcom")
    assert_select "h1", "CAPCOM"
    assert_select "title", "CAPCOM · Collection · gameble"

    publish_hall_of_fame_draft
    get library_set_path(locale: :en, kind: "hall_of_fame", key: "phenomenes")
    assert_select "h1", "The Phenomena"
  end

  test "an unknown kind, an unknown key or a key of another kind is not found" do
    publish_sets_draft
    sign_in(accounts_players(:player))

    get "/en/library/nope/rpg"
    assert_response :not_found

    get library_set_path(locale: :en, kind: "theme", key: "nope")
    assert_response :not_found

    get library_set_path(locale: :en, kind: "studio", key: "horror")
    assert_response :not_found

    get library_set_path(locale: :en, kind: "ufo", key: "rpg")
    assert_response :not_found
  end

  test "with no season published no album is found" do
    catalog_seasons(:one).update_columns(status: "draft", published_at: nil)
    sign_in(accounts_players(:player))

    get library_set_path(locale: :en, kind: "theme", key: "rpg")
    assert_response :not_found
  end

  test "no database id reaches the album" do
    season = publish_sets_draft
    player = accounts_players(:player)
    hold(player, set_members(season, "horror").first, 2)
    sign_in(player)
    ids = [ player.id ] + Catalog::Set.where(season_id: season.id).ids + Catalog::CardSeason.where(season_id: season.id).ids

    get library_set_path(locale: :en, kind: "theme", key: "horror")

    html = css_select("main").sole.to_html.gsub(/\d+\/\d+|value="\d+"|max="\d+"|\b(19|20)\d\d\b|x\d+|\d+ cop(y|ies)|\d+ cards?|seed-\d+-\d+|data-card-art-(width|height)-value="\d+"|width="\d+"|height="\d+"|\/seasons\/\d+|[Ss]eason \d+|>\d+</, "")
    ids.each { assert_no_match(/\b#{it}\b/, html) }
    assert_select "[data-id]", false
  end

  test "the screens an album opens from name themselves for its back button and mark the album last opened" do
    season = publish_sets_draft
    player = accounts_players(:player)
    set_members(season, "horror").first(2).each { hold(player, it, 1) }
    sign_in(player)

    get library_path(locale: :en)
    assert_select "header.top-bar[data-screen-label=Sets]"
    assert_select ".top-bar__start--phone-previous", false
    assert_select ".set-entry[data-controller=last-album][data-action='turbo:frame-load->last-album#mark'] a.set-row"

    get library_cards_path(locale: :en)
    assert_select "header.top-bar[data-screen-label=Collection]"

    get home_path(locale: :en)
    assert_select ".hub-sets[data-controller=last-album] a.set-row"
  end
end
