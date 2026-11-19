require "test_helper"
require_relative "../support/catalog_seeds"
require_relative "../support/game_sets"
require_relative "../support/library_requests"
require_relative "../support/steam_sign_in"

# One set judged by the whole Brotherhood's first discoveries, open to
# visitors: no tiers, no goal, each found card with its pioneer.
class BrotherhoodSetsControllerTest < ActionDispatch::IntegrationTest
  include CatalogSeeds
  include GameSets
  include LibraryRequests
  include SteamSignIn

  def discover(player, card_season_id, at: Time.current)
    Game::FirstDiscovery.create!(card_season_id:, player_id: player.id, discovered_at: at)
  end

  def slug(card_season_id) = Catalog::CardSeason.find(card_season_id).card.slug

  def view(card_season_id) =Catalog::CardViews.call([ card_season_id ], locale: :en).fetch(card_season_id)

  def label(card_season_id, words)
    card = view(card_season_id)
    [ card.title, card.publisher.presence, card.year, I18n.t("catalog.rarity.#{card.rarity}", locale: :en), words ].compact.join(", ")
  end

  def labels = css_select(".brotherhood-set__grid > li > a.card-link").map { it["aria-label"] }
  def count = css_select(".set-album__count").sole.text.squish
  def value_text = css_select("progress.set-album__bar").sole["aria-valuetext"]

  def earlier_edition(card_season_id)
    member = Catalog::CardSeason.find(card_season_id)
    Catalog::CardSeason.insert_all!([ { card_id: member.card_id, season_id: catalog_seasons(:one).id, prestige_score: 0.5, rating: 80.0,
      rarity: member.rarity_before_type_cast, number: 900 } ], returning: :id).rows.flatten.sole
  end

  setup do
    Game::FirstDiscovery.delete_all
    @lea = accounts_players(:player)
    @lea.update_columns(persona_name: "Léa", visibility: "public")
  end

  test "a visitor reads the set judged by the Brotherhood: its count without ticks, found cards with their pioneer, the others to discover" do
    season = publish_sets_draft
    members = set_members(season, "horror")
    discover(@lea, members[0])
    discover(accounts_players(:banned), members[2])

    get brotherhood_set_path(locale: :en, kind: "theme", key: "horror")

    assert_response :success
    assert_select "title", "Horror · The Great Inventory · Gameble"
    assert_select "p.top-bar__title", "The Great Inventory"
    assert_select "h1#set-album-heading[tabindex='-1'][autofocus]", "Horror"
    assert_equal "2/16", count
    assert_equal "2 cards discovered out of 16", value_text
    assert_select ".set-album__ticks, .set-row__tick, .set-album__actions, .set-album__stamp", false
    assert_select ".brotherhood-set__grid > li.brotherhood-card", 16
    assert_select ".brotherhood-set__grid .card--not-owned", 14
    assert_select ".brotherhood-card__badge, .collection-slot__copies, .collection-slot__new", false
    assert_equal label(members[0], "discovered by Léa"), labels[0]
    assert_equal label(members[1], "to discover"), labels[1]
    assert_equal label(members[2], "discovered by anonymous"), labels[2]
    assert_select ".brotherhood-card:nth-child(1) .brotherhood-card__pioneer", "Léa"
    assert_select ".brotherhood-card:nth-child(3) .brotherhood-card__pioneer[aria-hidden=true]", "anonymous"
    assert_select ".brotherhood-card:nth-child(2) .brotherhood-card__pioneer[aria-hidden=true]", "To discover"
    context = { from: "inventory", set_key: "horror", set_kind: "theme" }.to_query
    assert_equal "/en/cards/#{slug(members[0])}/seasons/#{season.number}?#{context}",
      css_select(".brotherhood-set__grid > li > a.card-link").first["href"]
    assert_select "[data-group=state] .filter-chip__box", 3
    assert_equal %w[Discovered All To\ discover], css_select("[data-group=state] .filter-chip__text").map(&:text)
    assert_select ".brotherhood-set__join", /Join the Brotherhood to discover the missing cards/
    assert_select "[style]", false
  end

  test "the pioneer reads YOU on their cards, and MY DISCOVERIES keeps only them" do
    season = publish_sets_draft
    members = set_members(season, "horror")
    discover(@lea, members[3])
    discover(accounts_players(:moderator), members[4])
    sign_in(@lea)

    get brotherhood_set_path(locale: :en, kind: "theme", key: "horror", state: [ "mine" ])

    assert_response :success
    assert_select ".brotherhood-set__grid > li", 1
    assert_select ".brotherhood-card--mine .brotherhood-card__badge[aria-hidden=true]", "YOU"
    assert_select ".brotherhood-card--mine .brotherhood-card__pioneer", "You"
    assert_equal [ label(members[3], "discovered by you") ], labels
    assert_select "[data-group=state] .filter-chip__box[value=mine][checked]"
    assert_select ".brotherhood-set__join", false

    get brotherhood_set_path(locale: :en, kind: "theme", key: "horror", state: [ "undiscovered" ])

    assert_select ".brotherhood-set__grid > li", 14
  end

  test "a set every card of which has a pioneer carries the stamp, in French" do
    season = publish_franchises_and_studios_draft
    set_members(season, "tom-clancy").each { discover(@lea, it) }

    get brotherhood_set_path(locale: :fr, kind: "franchise", key: "tom-clancy")

    assert_select ".set-album__title .set-album__stamp", "Entièrement découvert"
    assert_equal "3/3", count
    assert_equal "3 cartes découvertes sur 3", value_text
    assert_select "[data-group=state] .filter-chip__text", "Découvertes"
  end

  test "the current season scope leaves out a card found only in an earlier edition, and every link keeps it" do
    season = publish_sets_draft
    members = set_members(season, "horror")
    discover(@lea, earlier_edition(members[0]))

    get brotherhood_set_path(locale: :en, kind: "theme", key: "horror")
    assert_equal "1/16", count

    get brotherhood_set_path(locale: :en, kind: "theme", key: "horror", seasons: "current")
    assert_equal "0/16", count
    assert_select ".brotherhood-set__grid .card--not-owned", 16
    assert_select "form.filters input[type=hidden][name=seasons][value=current]"
    assert_select "a.filters__clear[href='/en/inventory/theme/horror?seasons=current']"
    assert_includes css_select(".brotherhood-set__grid > li > a.card-link").first["href"], "seasons=current"
  end

  test "a card opened from the set goes back to it, its neighbours keeping the context" do
    season = publish_sets_draft
    members = set_members(season, "horror")

    get card_season_path(locale: :en, slug: slug(members[1]), number: season.number, set_kind: "theme", set_key: "horror", from: "inventory")

    assert_response :success
    assert_select ".top-bar__phone-back[href='/en/inventory/theme/horror']", /Great Inventory/
    assert_select "a[href*='from=inventory'][href*='set_key=horror']"
  end

  test "an unknown set is not found" do
    publish_sets_draft

    get brotherhood_set_path(locale: :en, kind: "theme", key: "nowhere")

    assert_response :not_found
  end
end
