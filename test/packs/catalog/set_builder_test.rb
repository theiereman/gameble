require "test_helper"

# Catalog::SetBuilder (CAP-6): the publisher sets, genre tomes and
# best-rated-of-the-year sets of a season, built from its rows without the
# database.
class Catalog::SetBuilderTest < ActiveSupport::TestCase
  # Card-season ids start at 1_000 so they never equal a card id.
  def row(card_id, release_date: Date.new(2000, 1, 1), publisher: nil, genres: [], rating: 80, prestige_score: 1.0)
    Catalog::SeasonRows::Row.new(id: 1_000 + card_id, card_id:, prestige_score:, rating: BigDecimal(rating.to_s),
      release_date:, publisher:, genres:)
  end

  def ids(*card_ids) = card_ids.map { |card_id| 1_000 + card_id }

  def sizes(sets) = sets.map { |set| set[:members].size }

  # Publisher sets

  test "a publisher needs five cards; members by release date, then card id" do
    rows = [
      row(5, publisher: "A", release_date: Date.new(2010, 1, 1)),
      row(3, publisher: "A", release_date: Date.new(2009, 1, 1)),
      row(1, publisher: "A", release_date: Date.new(2010, 1, 1)),
      row(4, publisher: "A", release_date: Date.new(2001, 1, 1)),
      row(2, publisher: "A", release_date: Date.new(2012, 1, 1))
    ] + (6..9).map { |id| row(id, publisher: "B") } + (10..20).map { |id| row(id) }

    sets = Catalog::SetBuilder.publishers(rows)

    assert_equal [ { kind: "publisher", key: "a", params: { "publisher" => "A" }, members: ids(4, 3, 1, 5, 2) } ], sets
  end

  test "publisher keys are taken in byte order, the first unused of base, base-2, …" do
    names = [ "foo-bar", "Foo Bar 2", "Foo Bar", "株式会社" ]
    rows = names.each_with_index.flat_map { |name, index| (1..5).map { |n| row(index * 10 + n, publisher: name) } }

    sets = Catalog::SetBuilder.publishers(rows)

    assert_equal [ [ "Foo Bar", "foo-bar" ], [ "Foo Bar 2", "foo-bar-2" ], [ "foo-bar", "foo-bar-3" ], [ "株式会社", "publisher" ] ],
      sets.map { |set| [ set[:params]["publisher"], set[:key] ] }
  end

  test "a name with Latin letters keeps them in its key" do
    rows = (1..5).map { |n| row(n, publisher: "株式会社X") }

    assert_equal [ "x" ], Catalog::SetBuilder.publishers(rows).map { |set| set[:key] }
  end

  # Tomes

  {
    10 => [ 10 ], 44 => [ 44 ], 45 => [ 23, 22 ], 75 => [ 25, 25, 25 ], 89 => [ 30, 30, 29 ]
  }.each do |count, expected|
    test "a genre of #{count} cards gives volumes of #{expected.join("/")}" do
      rows = (1..count).map { |id| row(id, genres: [ "action" ]) }

      sets = Catalog::SetBuilder.tomes(rows)

      assert_equal expected, sizes(sets)
      assert_equal (1..expected.size).map { |i| "action-#{i}" }, sets.map { |set| set[:key] }
      assert_equal (1..expected.size).map { |i| { "genre" => "action", "volume" => i, "volumes" => expected.size } }, sets.map { |set| set[:params] }
      assert_equal ids(*1..count), sets.flat_map { |set| set[:members] }
    end
  end

  test "a tome's cards follow release date, then card id, across consecutive volumes" do
    rows = (1..45).map { |id| row(id, genres: [ "rpg" ], release_date: Date.new(2000 + (45 - id) / 2, 1, 1)) }

    sets = Catalog::SetBuilder.tomes(rows)

    expected = rows.sort_by { |r| [ r.release_date, r.card_id ] }.map(&:id)
    assert_equal expected.first(23), sets.first[:members]
    assert_equal expected.last(22), sets.last[:members]
  end

  test "a genre key keeps the genre as given" do
    sets = Catalog::SetBuilder.tomes((1..12).map { |id| row(id, genres: [ "free_to_play" ]) })

    assert_equal [ "free_to_play-1" ], sets.map { |set| set[:key] }
    assert_match Catalog::Set::KEY_FORMAT, sets.first[:key]
  end

  test "a card sits in the tome of its first genre only, and in none without genre" do
    sets = Catalog::SetBuilder.tomes([ row(1, genres: []), row(2, genres: [ "rpg", "action" ]) ])

    assert_equal [ { kind: "tome", key: "rpg-1", params: { "genre" => "rpg", "volume" => 1, "volumes" => 1 }, members: ids(2) } ], sets
  end

  # Best rated of the year

  test "one set per release year, at most ten cards" do
    rows = (1..12).map { |id| row(id, release_date: Date.new(2011, 3, 1)) } +
      (13..21).map { |id| row(id, release_date: Date.new(2012, 3, 1)) } +
      (22..31).map { |id| row(id, release_date: Date.new(2013, 3, 1)) }

    sets = Catalog::SetBuilder.best_of_year(rows)

    assert_equal [ "2011", "2012", "2013" ], sets.map { |set| set[:key] }
    assert_equal [ { "year" => 2011 }, { "year" => 2012 }, { "year" => 2013 } ], sets.map { |set| set[:params] }
    assert_equal [ 10, 9, 10 ], sizes(sets)
  end

  test "best of the year ranks by rating, then prestige, then card id" do
    year = Date.new(2011, 6, 1)
    # Ranks 10 and 11 share a rating: the higher prestige gets in.
    rows = (1..9).map { |id| row(id, release_date: year, rating: 99 - id) } + [
      row(20, release_date: year, rating: 50, prestige_score: 3.0),
      row(21, release_date: year, rating: 50, prestige_score: 2.0),
      row(30, release_date: year, rating: 40, prestige_score: 9.0)
    ]

    assert_equal ids(*1..9, 20), Catalog::SetBuilder.best_of_year(rows).sole[:members]

    # Same rating and prestige: the lower card id ranks first.

    rows = [ row(31, release_date: year, rating: 40), row(30, release_date: year, rating: 40), row(5, release_date: year, rating: 41) ]
    assert_equal ids(5, 30, 31), Catalog::SetBuilder.best_of_year(rows).sole[:members]
  end

  # All kinds

  test "one card belongs to its publisher set, its tome and its year's best" do
    rows = (1..5).map { |id| row(id, publisher: "A", genres: [ "action" ], release_date: Date.new(2011, 1, 1)) }

    sets = Catalog::SetBuilder.call(rows)

    assert_equal [ "publisher", "tome", "best_of_year" ], sets.map { |set| set[:kind] }
    sets.each { |set| assert_includes set[:members], ids(1).first }
  end

  test "no publisher and no genre leaves only the years' best" do
    rows = (1..21).map { |id| row(id, release_date: Date.new(2000 + id % 3, 1, 1)) }

    assert_equal [ "best_of_year" ] * 3, Catalog::SetBuilder.call(rows).map { |set| set[:kind] }
  end

  test "15,000 rows build quickly, every card in its tome and every key well-formed" do
    genres = %w[action adventure rpg strategy indie simulation casual sports racing free_to_play]
    rows = (1..15_000).map do |id|
      row(id, publisher: "Publisher #{id % 700}", genres: [ genres[id % genres.size] ], rating: 50 + id % 50,
        prestige_score: (id * 7_919 % 15_000).to_f, release_date: Date.new(1990 + id % 36, 1 + id % 12, 1))
    end

    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    sets = Catalog::SetBuilder.call(rows)
    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started

    assert_operator elapsed, :<, 5
    by_kind = sets.group_by { |set| set[:kind] }
    assert_equal 700, by_kind["publisher"].size
    assert_equal 36, by_kind["best_of_year"].size
    assert_equal rows.map(&:id).sort, by_kind["tome"].flat_map { |set| set[:members] }.sort
    assert_equal 500, by_kind["tome"].size
    assert by_kind["tome"].all? { |set| set[:members].size == 30 }
    assert sets.all? { |set| Catalog::Set::KEY_FORMAT.match?(set[:key]) }
    assert_equal sets.size, sets.map { |set| [ set[:kind], set[:key] ] }.uniq.size
  end
end
