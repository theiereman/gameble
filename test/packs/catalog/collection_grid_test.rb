require "test_helper"
require_relative "../../support/catalog_seeds"

# Catalog::CollectionGrid (CAP-6, story 10.1): the ordered cards of the whole
# season or of one set, their genres, and the filters: genre, rarity, set and
# text.
class Catalog::CollectionGridTest < ActiveSupport::TestCase
  include CatalogSeeds

  setup do
    @season = publish_sets_draft
  end

  def members(key)
    set = Catalog::Set.find_by!(season_id: @season.id, key:)
    Catalog::SetMembership.where(set_id: set.id).order(:position, :id).pluck(:card_season_id)
  end

  def tome_genre(card_season_id)
    tome = Catalog::Set.joins(:memberships).find_by(kind: "tome", catalog_set_memberships: { card_season_id: })
    tome&.params&.fetch("genre")
  end

  test "the whole season: its cards with a rarity by number then id, the tomes' genres, in one query and a lazy relation" do
    grid = nil
    assert_queries_count(1) { grid = Catalog::CollectionGrid.call(season: @season) }

    assert_nil grid.set
    assert_equal %w[action rpg], grid.genres
    assert_empty grid.chosen_genres
    expected = Catalog::CardSeason.where(season_id: @season.id).where.not(rarity: nil).order(:number, :id).ids
    assert_equal 150, expected.size
    assert_equal expected, grid.card_seasons.pluck(:id)
    assert_equal 150, grid.card_seasons.count
  end

  test "a card-season without a rarity is left out" do
    draft = seed_card_seasons([ 1.0 ], season: Catalog::Season.create!(status: :draft, number: Catalog::Season.next_number))
    id = Catalog::CardSeason.where(season_id: draft.id).sole.id
    Catalog::CardSeason.where(id:).update_all(season_id: @season.id)

    assert_not_includes Catalog::CollectionGrid.call(season: @season).card_seasons.pluck(:id), id
  end

  test "a genre keeps the cards of its tomes; an unknown genre is ignored" do
    grid = Catalog::CollectionGrid.call(season: @season, genres: [ "rpg" ])

    assert_equal [ "rpg" ], grid.chosen_genres
    assert_equal members("rpg-1").sort, grid.card_seasons.pluck(:id).sort
    assert grid.card_seasons.pluck(:id).all? { tome_genre(it) == "rpg" }

    %w[strategy Action].push(nil, "").each do |genre|
      grid = Catalog::CollectionGrid.call(season: @season, genres: [ genre ])
      assert_empty grid.chosen_genres
      assert_equal 150, grid.card_seasons.count
    end
  end

  test "a set by kind and key: its cards by membership position, its cards' genres, in two queries" do
    grid = nil
    assert_queries_count(2) { grid = Catalog::CollectionGrid.call(season: @season, kind: "tome", key: "action-1") }

    assert_equal Catalog::SetSlots::SetRef.new(kind: "tome", key: "action-1", params: { "genre" => "action", "volume" => 1, "volumes" => 3 }), grid.set
    assert_equal %w[action], grid.genres
    assert_equal members("action-1"), grid.card_seasons.pluck(:id)
  end

  test "a set's genres are those of its cards' tomes, and filter it" do
    best = members("2011")
    genres = best.map { tome_genre(it) }.compact.uniq.sort
    assert_operator genres.size, :>=, 2

    grid = Catalog::CollectionGrid.call(season: @season, kind: :best_of_year, key: "2011", genres: [ genres.last ])

    assert_equal genres, grid.genres
    assert_equal [ genres.last ], grid.chosen_genres
    assert_equal best.select { tome_genre(it) == genres.last }, grid.card_seasons.pluck(:id)
  end

  test "several genres are an OR; a rarity then narrows them, an AND" do
    both = Catalog::CollectionGrid.call(season: @season, genres: %w[rpg action])
    assert_equal %w[action rpg], both.chosen_genres
    assert_equal members("rpg-1").size + %w[action-1 action-2 action-3].sum { members(it).size }, both.card_seasons.count

    rarity = Catalog::CardSeason.where(id: both.card_seasons.select(:id)).pick(:rarity)
    narrowed = Catalog::CollectionGrid.call(season: @season, genres: %w[rpg action], rarities: [ rarity ])
    assert_equal [ rarity ], narrowed.chosen_rarities
    expected = Catalog::CardSeason.where(id: both.card_seasons.select(:id), rarity:).ids
    assert_equal expected.sort, narrowed.card_seasons.pluck(:id).sort

    two = Catalog::CollectionGrid.call(season: @season, rarities: %w[common legendary nope])
    assert_equal %w[common legendary], two.chosen_rarities
    assert_equal Catalog::CardSeason.where(season_id: @season.id, rarity: %w[common legendary]).count, two.card_seasons.count
  end

  test "sets asked as kind:key keep the cards of any of them; unknown sets and a set's own page ignore them" do
    grid = Catalog::CollectionGrid.call(season: @season, sets: %w[tome:action-1 tome:rpg-1 tome:nope publisher nonsense])

    assert_equal %w[action-1 rpg-1], grid.chosen_sets.map(&:key)
    assert_equal (members("action-1") + members("rpg-1")).sort, grid.card_seasons.pluck(:id).sort

    inside = Catalog::CollectionGrid.call(season: @season, kind: "tome", key: "action-1", sets: [ "tome:rpg-1" ])
    assert_empty inside.chosen_sets
    assert_equal members("action-1"), inside.card_seasons.pluck(:id)
  end

  test "a text is found in the title in the locale or in the publisher, whatever its case; wildcards are literal" do
    by_title = Catalog::CollectionGrid.call(season: @season, query: "seed 12", locale: "fr")
    assert_equal [ 12 ] + (120..129).to_a, by_title.card_seasons.map { Integer(it.card.texts.find_by!(locale: "fr").title[/\d+/]) }.sort

    by_publisher = Catalog::CollectionGrid.call(season: @season, query: "q")
    assert_equal 4, by_publisher.card_seasons.count

    assert_equal 0, Catalog::CollectionGrid.call(season: @season, query: "%").card_seasons.count
    assert_equal 0, Catalog::CollectionGrid.call(season: @season, query: "_eed").card_seasons.count
    assert_equal 150, Catalog::CollectionGrid.call(season: @season, query: "  ").card_seasons.count

    both = Catalog::CollectionGrid.call(season: @season, query: "seed 12", genres: %w[rpg])
    assert_operator both.card_seasons.count, :<, by_title.card_seasons.count
  end

  test "a set the season does not hold under that kind and key is nil" do
    assert_nil Catalog::CollectionGrid.call(season: @season, kind: "tome", key: "action-9")
    assert_nil Catalog::CollectionGrid.call(season: @season, kind: "publisher", key: "action-1")
    assert_nil Catalog::CollectionGrid.call(season: catalog_seasons(:one), kind: "tome", key: "action-1")
  end

  test "paged in SQL" do
    page = Catalog::CollectionGrid.call(season: @season).card_seasons.offset(60).limit(60)

    assert_equal Catalog::CardSeason.where(season_id: @season.id).order(:number, :id).ids[60, 60], page.pluck(:id)
  end
end
