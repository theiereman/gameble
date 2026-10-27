require "test_helper"
require_relative "../../support/catalog_seeds"
require_relative "../../support/game_sets"

# Game::SetShowcases: what a set progress tile shows of a player's sets.
class Game::SetShowcasesTest < ActiveSupport::TestCase
  include CatalogSeeds
  include GameSets

  setup do
    @player = accounts_players(:player)
    @season, @cards = published_cards(200)
    @free = @cards.dup
  end

  def take(count) = @free.shift(count)

  def rarity(ids, tier) = Catalog::CardSeason.where(id: ids).update_all(rarity: Catalog::Rarity::TIERS.key(tier))

  def showcases(set_ids, player: @player) = Game::SetShowcases.call(player, set_ids:, season: @season, locale: :en)

  def slug(card_season_id) = Catalog::CardSeason.find(card_season_id).card.slug

  def small_set(members, key) = insert_set(members, { complete: members.size }, kind: "franchise", key:, params: { "franchise" => key }, season: @season)

  test "a set of five cards or fewer shows every member in set order, a missing one by the set's rarity" do
    members = take(3)
    set = small_set(members, "halo")
    rarity([ members[1] ], :epic)
    hold_all(@player, [ members[0], members[2] ])

    showcase = showcases([ set ]).fetch(set)

    assert_equal [ [ slug(members[0]), "common", true ], [ nil, "epic", false ], [ slug(members[2]), "common", true ] ],
      showcase.slots.map { [ it.card&.id, it.rarity, it.owned? ] }
    assert_equal 0, showcase.others
  end

  test "a larger set shows its three rarest held games, ties in set order, at their best edition, and counts the others held" do
    members = take(12)
    set = insert_theme(members, key: "roguelike", season: @season)
    rarity([ members[2], members[8] ], :rare)
    rarity([ members[5] ], :legendary)
    hold_all(@player, members.first(9))
    card_id = Catalog::CardSeason.find(members[0]).card_id
    epic_edition = Catalog::CardSeason.insert_all!([ { card_id:, season_id: catalog_seasons(:one).id, prestige_score: 0.5, rating: 90,
      rarity: Catalog::Rarity::TIERS.key(:epic), number: 900 } ], returning: :id).rows.flatten.sole
    hold_all(@player, [ epic_edition ])

    view_queries = []
    record = ->(*, payload) { view_queries << payload[:sql] if payload[:sql].include?("catalog_card_texts") }
    showcase = ActiveSupport::Notifications.subscribed(record, "sql.active_record") { showcases([ set ]).fetch(set) }

    assert_equal 3, view_queries.sole[/"catalog_card_seasons"."id" IN \(([^)]*)\)/, 1].split(",").size, "faces are read for the cards shown only"
    assert_equal [ [ slug(members[5]), "legendary" ], [ slug(members[0]), "epic" ], [ slug(members[2]), "rare" ] ],
      showcase.slots.map { [ it.card.id, it.rarity ] }
    assert_equal catalog_seasons(:one).number, showcase.slots.second.card.season_number
    assert_equal 6, showcase.others
  end

  test "each set names the game gained in it last; none timed, none named" do
    first = take(3)
    second = take(3)
    timed = small_set(first, "halo")
    untimed = small_set(second, "doom")
    latest = Time.utc(2026, 10, 20, 9)
    hold_all(@player, [ first[0] ], gained_at: latest - 1.day)
    hold_all(@player, [ first[1] ], gained_at: latest)
    hold_all(@player, second.first(2))

    result = showcases([ timed, untimed ])

    assert_equal [ slug(first[1]), latest ], [ result.fetch(timed).last_gained.card.id, result.fetch(timed).last_gained.gained_at ]
    assert_nil result.fetch(untimed).last_gained
  end

  test "three sets or forty cost the same two queries; a visitor or no set, none" do
    sets = (1..40).map { |index| [ insert_theme(members = take(5), key: "theme-#{index}", season: @season), members ] }
    sets.each { |_set, members| hold_all(@player, members.first(2)) }

    assert_queries_count(2) { assert_equal 3, showcases(sets.first(3).map(&:first)).size }
    assert_queries_count(2) { assert_equal 40, showcases(sets.map(&:first)).size }
    assert_queries_count(0) { assert_equal({}, showcases(sets.map(&:first), player: nil)) }
    assert_queries_count(0) { assert_equal({}, showcases([])) }
  end
end
