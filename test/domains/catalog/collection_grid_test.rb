require "test_helper"
require_relative "../../support/catalog_seeds"

# Catalog::CollectionGrid: the ordered cards of the whole season, or the
# tiles given, their genres (main themes), and the filters: genre, rarity,
# set and text.
class Catalog::CollectionGridTest < ActiveSupport::TestCase
  include CatalogSeeds

  setup do
    @season = publish_sets_draft
  end

  def members(key)
    set = Catalog::Set.find_by!(season_id: @season.id, key:)
    Catalog::SetMembership.where(set_id: set.id).order(:position, :id).pluck(:card_season_id)
  end

  def main_theme(card_season_id)
    Catalog::CardSeason.find(card_season_id).main_theme
  end

  test "the whole season: its cards with a rarity by number then id, their main themes, in one query and a lazy relation" do
    grid = nil
    assert_queries_count(1) { grid = Catalog::CollectionGrid.call(season: @season) }

    assert_equal %w[horror roguelike rpg], grid.genres
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

  test "a genre keeps the cards whose main theme it is; an unknown genre is ignored" do
    grid = Catalog::CollectionGrid.call(season: @season, genres: [ "rpg" ])

    assert_equal [ "rpg" ], grid.chosen_genres
    assert_equal members("rpg").sort, grid.card_seasons.pluck(:id).sort

    roguelike = Catalog::CollectionGrid.call(season: @season, genres: [ "roguelike" ])
    assert_equal 83, roguelike.card_seasons.count
    assert roguelike.card_seasons.pluck(:id).all? { main_theme(it) == "roguelike" }

    %w[strategy Roguelike].push(nil, "").each do |genre|
      grid = Catalog::CollectionGrid.call(season: @season, genres: [ genre ])
      assert_empty grid.chosen_genres
      assert_equal 150, grid.card_seasons.count
    end
  end

  test "several genres are an OR; a rarity then narrows them, an AND" do
    both = Catalog::CollectionGrid.call(season: @season, genres: %w[rpg roguelike])
    assert_equal %w[roguelike rpg], both.chosen_genres
    assert_equal members("roguelike").size, both.card_seasons.count

    rarity = Catalog::CardSeason.where(id: both.card_seasons.select(:id)).pick(:rarity)
    narrowed = Catalog::CollectionGrid.call(season: @season, genres: %w[rpg roguelike], rarities: [ rarity ])
    assert_equal [ rarity ], narrowed.chosen_rarities
    expected = Catalog::CardSeason.where(id: both.card_seasons.select(:id), rarity:).ids
    assert_equal expected.sort, narrowed.card_seasons.pluck(:id).sort

    two = Catalog::CollectionGrid.call(season: @season, rarities: %w[common legendary nope])
    assert_equal %w[common legendary], two.chosen_rarities
    assert_equal Catalog::CardSeason.where(season_id: @season.id, rarity: %w[common legendary]).count, two.card_seasons.count
  end

  test "sets asked as kind:key keep the cards of any of them, in the order asked; unknown sets are ignored" do
    grid = Catalog::CollectionGrid.call(season: @season, sets: %w[theme:rpg ufo:ufos theme:nope publisher nonsense])

    assert_equal %w[rpg ufos], grid.chosen_sets.map(&:key)
    assert_equal (members("rpg") + members("ufos")).sort, grid.card_seasons.pluck(:id).sort
    assert_equal [ { "theme" => "rpg" }, {} ], grid.chosen_sets.map(&:params)
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

  test "paged in SQL" do
    page = Catalog::CollectionGrid.call(season: @season).card_seasons.offset(60).limit(60)

    assert_equal Catalog::CardSeason.where(season_id: @season.id).order(:number, :id).ids[60, 60], page.pluck(:id)
  end

  def reprint(card_season_id, main_theme: nil, rarity: "legendary")
    @other ||= Catalog::Season.create!(status: :draft, number: Catalog::Season.next_number)
    card = Catalog::CardSeason.find(card_season_id)
    Catalog::CardSeason.create!(card_id: card.card_id, season: @other, prestige_score: 0.5, rating: 90, rarity:, main_theme:).id
  end

  test "tiles given: a genre matches their own main theme or their game's in the season, a set their game's membership, a rarity their own" do
    rpg = members("rpg").first
    roguelike = (members("roguelike") - members("rpg")).first
    shown_rpg = reprint(rpg)
    shown_roguelike = reprint(roguelike, main_theme: "rpg", rarity: "common")
    season = Catalog::CardSeason.where(season_id: @season.id).where.not(rarity: nil).ids
    cards = Catalog::CardSeason.where(id: season - [ rpg, roguelike ] + [ shown_rpg, shown_roguelike ])

    grid = Catalog::CollectionGrid.call(season: @season, cards:, genres: [ "rpg" ])
    assert_equal %w[horror roguelike rpg], grid.genres
    assert_equal (members("rpg") - [ rpg ] + [ shown_rpg, shown_roguelike ]).sort, grid.card_seasons.pluck(:id).sort

    by_set = Catalog::CollectionGrid.call(season: @season, cards:, sets: %w[theme:rpg])
    assert_equal (members("rpg") - [ rpg ] + [ shown_rpg ]).sort, by_set.card_seasons.pluck(:id).sort

    legendary = Catalog::CollectionGrid.call(season: @season, cards:, rarities: %w[legendary]).card_seasons.pluck(:id)
    assert_includes legendary, shown_rpg
    assert_not_includes legendary, rpg
  end
end
