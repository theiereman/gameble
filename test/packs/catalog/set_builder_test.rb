require "test_helper"

# Catalog::SetBuilder: the theme sets and the UFOs of a season, built from
# its rows without the database, with their tiers.
class Catalog::SetBuilderTest < ActiveSupport::TestCase
  # Card-season ids start at 1_000 so they never equal a card id.
  def row(card_id, release_date: Date.new(2000, 1, 1), genres: [], rating: 80, prestige_score: 1.0)
    Catalog::SeasonRows::Row.new(id: 1_000 + card_id, card_id:, prestige_score:, prestige_score_version: 2, rating: BigDecimal(rating.to_s),
      release_date:, genres:)
  end

  def ids(*card_ids) = card_ids.map { |card_id| 1_000 + card_id }

  # Theme sets

  test "a card joins every theme among its genres; members by release date, then card id" do
    rows = [
      row(5, genres: %w[roguelike deckbuilder horror], release_date: Date.new(2010, 1, 1)),
      row(3, genres: %w[horror], release_date: Date.new(2009, 1, 1)),
      row(1, genres: %w[roguelike], release_date: Date.new(2010, 1, 1)),
      row(4, genres: %w[horror roguelike], release_date: Date.new(2001, 1, 1))
    ]

    sets = Catalog::SetBuilder.themes(rows)

    assert_equal [ [ "roguelike", ids(4, 1, 5) ], [ "deckbuilder", ids(5) ], [ "horror", ids(4, 3, 5) ] ],
      sets.map { |set| [ set[:key], set[:members] ] }
    assert_equal [ "theme" ], sets.map { |set| set[:kind] }.uniq
    assert_equal [ { "theme" => "roguelike" }, { "theme" => "deckbuilder" }, { "theme" => "horror" } ], sets.map { |set| set[:params] }
  end

  test "theme sets follow the theme list's order, and a theme no card has makes no set" do
    rows = [ row(1, genres: %w[adult]), row(2, genres: %w[souls_like]), row(3, genres: %w[rpg]) ]

    assert_equal %w[souls_like rpg adult], Catalog::SetBuilder.themes(rows).map { |set| set[:key] }
  end

  test "every theme key is a well-formed set key" do
    assert_equal 42, Catalog::Themes.keys.size
    assert Catalog::Themes.keys.all? { |key| Catalog::Set::KEY_FORMAT.match?(key) }
    assert_match Catalog::Set::KEY_FORMAT, Catalog::SetBuilder::UFOS
  end

  test "a theme of 7 cards needs 1, 2 and 4 of them for bronze, silver and gold, and 7 to complete" do
    sets = Catalog::SetBuilder.themes((1..7).map { |id| row(id, genres: %w[pirates]) })

    assert_equal({ "bronze" => 1, "silver" => 2, "gold" => 4, "complete" => 7 }, sets.sole[:tiers])
  end

  {
    1 => [ 1, 1, 1, 1 ], 10 => [ 1, 3, 5, 10 ], 30 => [ 3, 8, 15, 30 ], 2_084 => [ 209, 521, 1_042, 2_084 ]
  }.each do |count, expected|
    test "a theme of #{count} cards has the tiers #{expected.join("/")}, rounded up" do
      assert_equal %w[bronze silver gold complete].zip(expected).to_h, Catalog::Themes.tiers(count)
    end
  end

  # The UFOs

  test "the cards of no theme are the UFOs, in release order, complete only" do
    rows = [ row(2, release_date: Date.new(2012, 1, 1)), row(1, genres: %w[rpg]), row(3, release_date: Date.new(2011, 1, 1)) ]

    assert_equal [ { kind: "ufo", key: "ufos", params: {}, members: ids(3, 2), tiers: { "complete" => 2 } } ],
      Catalog::SetBuilder.ufos(rows)
  end

  test "a season where every card has a theme has no UFOs" do
    assert_empty Catalog::SetBuilder.ufos([ row(1, genres: %w[rpg]) ])
  end

  test "a genre outside the theme list is no theme: its card is in the UFOs" do
    rows = [ row(1, genres: %w[action]) ]

    assert_empty Catalog::SetBuilder.themes(rows)
    assert_equal ids(1), Catalog::SetBuilder.ufos(rows).sole[:members]
  end

  # All kinds

  test "a publication builds the theme sets, then the UFOs, every card in at least one" do
    rows = [ row(1, genres: %w[roguelike deckbuilder horror]), row(2), row(3, genres: %w[rpg]) ]

    sets = Catalog::SetBuilder.call(rows)

    assert_equal [ [ "theme", "roguelike" ], [ "theme", "deckbuilder" ], [ "theme", "horror" ], [ "theme", "rpg" ], [ "ufo", "ufos" ] ],
      sets.map { |set| [ set[:kind], set[:key] ] }
    assert_equal ids(1, 2, 3), sets.flat_map { |set| set[:members] }.uniq.sort
  end

  test "15,000 rows build quickly, every card in a set and every key well-formed" do
    themes = Catalog::Themes.keys
    rows = (1..15_000).map do |id|
      genres = id % 25 == 0 ? [] : [ themes[id % themes.size], themes[(id * 7) % themes.size] ].uniq
      row(id, genres:, prestige_score: (id * 7_919 % 15_000).to_f, release_date: Date.new(1990 + id % 36, 1 + id % 12, 1))
    end

    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    sets = Catalog::SetBuilder.call(rows)
    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started

    assert_operator elapsed, :<, 5
    by_kind = sets.group_by { |set| set[:kind] }
    assert_equal 42, by_kind["theme"].size
    assert_equal 600, by_kind["ufo"].sole[:members].size
    assert_equal rows.map(&:id).sort, sets.flat_map { |set| set[:members] }.uniq.sort
    assert sets.all? { |set| Catalog::Set::KEY_FORMAT.match?(set[:key]) }
    assert_equal sets.size, sets.map { |set| [ set[:kind], set[:key] ] }.uniq.size
  end
end
