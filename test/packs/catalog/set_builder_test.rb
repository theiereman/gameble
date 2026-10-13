require "test_helper"

# Catalog::SetBuilder: the theme, franchise, studio and hall of fame sets
# and the UFOs of a season, built from its rows without the database, with
# their tiers.
class Catalog::SetBuilderTest < ActiveSupport::TestCase
  # Card-season ids start at 1_000 so they never equal a card id.
  def row(card_id, release_date: Date.new(2000, 1, 1), genres: [], rating: 80, prestige_score: 1.0, title: "Game #{card_id}",
          developers: [], franchises: [], publisher: nil, review_count: nil)
    Catalog::SeasonRows::Row.new(id: 1_000 + card_id, card_id:, prestige_score:, prestige_score_version: 2, rating: BigDecimal(rating.to_s),
      release_date:, genres:, title:, developers:, franchises:, publisher:, review_count:)
  end

  # Rows of the franchise `name`, one per title, card ids from `first`.
  def franchise_rows(name, titles, first: 1, **options)
    titles.each_with_index.map { |title, index| row(first + index, title:, franchises: [ name ], **options) }
  end

  # Rows of the first developer `name`, one per review count, card ids from `first`.
  def studio_rows(name, review_counts, first: 1)
    review_counts.each_with_index.map { |review_count, index| row(first + index, developers: [ name ], review_count:) }
  end

  def summary(sets) = sets.map { |set| [ set[:key], set[:params], set[:members] ] }

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

  # Franchises

  test "a franchise of 3 games whose titles carry its name is a set, its suffix dropped, complete only" do
    rows = franchise_rows("Tom Clancy Franchise", [ "Tom Clancy's Rainbow Six", "Tom Clancy's The Division", "Tom Clancy's Ghost Recon" ])
    rows[0] = rows[0].with(release_date: Date.new(2010, 1, 1))

    assert_equal [ { kind: "franchise", key: "tom-clancy", params: { "franchise" => "Tom Clancy" }, members: ids(2, 3, 1),
      tiers: { "complete" => 3 } } ], Catalog::SetBuilder.franchises(rows)
  end

  test "names differing by case or suffix make one set, named after the variant most games carry" do
    rows = franchise_rows("FINAL FANTASY", [ "FINAL FANTASY VII", "FINAL FANTASY X" ]) +
      franchise_rows("Final Fantasy Series", [ "Final Fantasy XIV" ], first: 3)

    assert_equal [ [ "final-fantasy", { "franchise" => "FINAL FANTASY" }, ids(1, 2, 3) ] ], summary(Catalog::SetBuilder.franchises(rows))
  end

  test "names differing only by punctuation inside a word make one set, keyed by the chosen name" do
    rows = franchise_rows("Watch_Dogs", [ "Watch_Dogs", "Watch_Dogs 2" ]) + franchise_rows("WatchDogs", [ "Watch Dogs: Legion" ], first: 3) +
      franchise_rows("S.T.A.L.K.E.R.", [ "S.T.A.L.K.E.R.: Shadow of Chernobyl" ], first: 4) +
      franchise_rows("STALKER", [ "STALKER 2", "STALKER Clear Sky" ], first: 5) +
      franchise_rows("Yu-Gi-Oh!", [ "Yu-Gi-Oh! Master Duel", "Yu-Gi-Oh! Duel Links" ], first: 7) +
      franchise_rows("YuGiOh", [ "YuGiOh Legacy" ], first: 9)

    assert_equal [ [ "stalker", { "franchise" => "STALKER" }, ids(4, 5, 6) ], [ "watch-dogs", { "franchise" => "Watch_Dogs" }, ids(1, 2, 3) ],
      [ "yu-gi-oh", { "franchise" => "Yu-Gi-Oh!" }, ids(7, 8, 9) ] ], summary(Catalog::SetBuilder.franchises(rows))
  end

  test "a studio's names differing only by punctuation make one set" do
    rows = studio_rows("Re-Logic", [ 50_000, nil ]) + studio_rows("ReLogic Inc.", [ nil ], first: 3)

    assert_equal [ [ "re-logic", { "studio" => "Re-Logic" }, ids(1, 2, 3) ] ], summary(Catalog::SetBuilder.studios(rows))
  end

  test "names whose keys are equal make one set" do
    rows = franchise_rows("Pokémon", [ "Pokémon Snap", "Pokémon Go" ]) + franchise_rows("Pokemon", [ "Pokemon Ranger" ], first: 3)

    assert_equal [ [ "pokemon", { "franchise" => "Pokémon" }, ids(1, 2, 3) ] ], summary(Catalog::SetBuilder.franchises(rows))
  end

  test "partly transliterable names of unrelated franchises keep apart" do
    rows = franchise_rows("ファイナルファンタジー 7", [ "ファイナルファンタジー 7", "ファイナルファンタジー 7 R", "ファイナルファンタジー 7 CC" ]) +
      franchise_rows("ドラゴンクエスト 7", [ "ドラゴンクエスト 7", "ドラゴンクエスト 7 R", "ドラゴンクエスト 7 3DS" ], first: 4)

    assert_equal 2, Catalog::SetBuilder.franchises(rows).map { |set| set[:key] }.uniq.size
  end

  test "on a tie the alphabetically first variant names the set; a game naming two variants counts once" do
    rows = [ row(1, title: "Sonic Mania", franchises: [ "SONIC™", "Sonic" ]), row(2, title: "Sonic Adventure", franchises: [ "Sonic" ]),
      row(3, title: "Sonic Frontiers", franchises: [ "sonic Series" ]) ]

    assert_equal [ [ "sonic", { "franchise" => "SONIC" }, ids(1, 2, 3) ] ], summary(Catalog::SetBuilder.franchises(rows))
  end

  test "a franchise of 2 games is no set" do
    assert_empty Catalog::SetBuilder.franchises(franchise_rows("Portal", [ "Portal", "Portal 2" ]))
  end

  test "a franchise named like a developer or a publisher of the season is no set" do
    developed = franchise_rows("Team17", [ "Team17 Worms", "Team17 Golf", "Team17 Overcooked" ])
    developed[0] = developed[0].with(developers: [ "Studio", "Team17" ])
    published = franchise_rows("Team17 Digital", [ "Team17 Digital A", "Team17 Digital B", "Team17 Digital C" ], first: 4)
    published << row(7, publisher: "Team17 Digital Ltd")

    assert_empty Catalog::SetBuilder.franchises(developed + published)
  end

  test "a franchise over unrelated titles sharing only a stopword is no set" do
    rows = franchise_rows("Estate Agent Simulator", [ "Clothing Store Simulator", "Supercar Collection Simulator", "Table Battle Simulator" ])

    assert_empty Catalog::SetBuilder.franchises(rows)
  end

  test "a franchise needs more than half of its titles to match" do
    rows = franchise_rows("Risen", [ "Risen", "Risen 2", "Dark Waters", "Elex" ])

    assert_empty Catalog::SetBuilder.franchises(rows)
    assert_equal [ "risen" ], Catalog::SetBuilder.franchises(rows.values_at(0, 1, 3)).map { |set| set[:key] }
  end

  test "a one-word name matches however short; a separator-free name matches the joined title words" do
    rows = franchise_rows("Ys", [ "Ys VIII", "Ys IX", "Ys Origin" ]) +
      franchise_rows("WatchDogs Franchise", [ "Watch_Dogs", "Watch_Dogs 2", "Watch Dogs: Legion" ], first: 4)

    assert_equal [ [ "watchdogs", { "franchise" => "WatchDogs" }, ids(4, 5, 6) ], [ "ys", { "franchise" => "Ys" }, ids(1, 2, 3) ] ],
      summary(Catalog::SetBuilder.franchises(rows))
  end

  test "Science Adventure and World of Darkness need no title to match" do
    rows = franchise_rows("Science Adventure Series", [ "Steins;Gate", "Chaos;Head", "Robotics;Notes" ]) +
      franchise_rows("World of Darkness", [ "Vampire: Bloodlines", "Werewolf: Earthblood", "Wraith" ], first: 4)

    assert_equal [ [ "science-adventure", { "franchise" => "Science Adventure" } ], [ "world-of-darkness", { "franchise" => "World of Darkness" } ] ],
      Catalog::SetBuilder.franchises(rows).map { |set| [ set[:key], set[:params] ] }
  end

  test "a card without an English title never matches" do
    assert_empty Catalog::SetBuilder.franchises(franchise_rows("Hitman", [ "Hitman", "Hitman 2", nil, nil ]))
  end

  test "a name with no Latin letter or digit still gets a valid key, unique to it" do
    rows = franchise_rows("ファイナルファンタジー", [ "ファイナルファンタジー VII", "ファイナルファンタジー X", "ファイナルファンタジー XII" ]) +
      franchise_rows("ドラゴンクエスト", [ "ドラゴンクエスト XI", "ドラゴンクエスト VIII", "ドラゴンクエスト III" ], first: 4)

    sets = Catalog::SetBuilder.franchises(rows)

    assert_equal [ "ドラゴンクエスト", "ファイナルファンタジー" ].sort, sets.map { |set| set[:params]["franchise"] }.sort
    assert sets.all? { |set| set[:key].match?(/\Ax-\h{12}\z/) && Catalog::Set::KEY_FORMAT.match?(set[:key]) }
    assert_equal 2, sets.map { |set| set[:key] }.uniq.size
  end

  # Studios

  test "a studio's names are one set once normalized, named after the variant most games carry, complete only" do
    rows = studio_rows("CAPCOM Co., Ltd.", [ 100, 25_000 ]) + studio_rows("Capcom", [ nil ], first: 3)

    assert_equal [ { kind: "studio", key: "capcom", params: { "studio" => "CAPCOM" }, members: ids(1, 2, 3), tiers: { "complete" => 3 } } ],
      Catalog::SetBuilder.studios(rows)
  end

  test "a game counts under its first developer only" do
    rows = studio_rows("Valve", [ 30_000, nil, nil ]) + studio_rows("Feral Interactive", [ 30_000, nil ], first: 4)
    rows[0] = rows[0].with(developers: [ "Valve", "Feral Interactive (Mac)" ])

    assert_equal [ [ "valve", { "studio" => "Valve" }, ids(1, 2, 3) ] ], summary(Catalog::SetBuilder.studios(rows))
  end

  test "a studio whose most-reviewed game is under 20,000 reviews, or of 2 games, is no set" do
    assert_empty Catalog::SetBuilder.studios(studio_rows("Quiet River", [ 19_999, 10, nil, 5_000, 1 ]))
    assert_empty Catalog::SetBuilder.studios(studio_rows("Big", [ 500_000, 400_000 ]))
    assert_equal 1, Catalog::SetBuilder.studios(studio_rows("Quiet River", [ 20_000, nil, nil ])).size
  end

  # Hall of fame

  def hall_of_fame_keys(rating, review_count)
    Catalog::SetBuilder.hall_of_fame([ row(1, rating:, review_count:) ]).map { |set| set[:key] }
  end

  {
    [ 97, 20_000 ] => [ "intouchables" ], [ 98, 999 ] => [ "pepites" ], [ 69, 20_000 ] => [ "mal-aimes" ],
    [ 40, 20_000 ] => [ "mal-aimes" ], [ 85, 200_000 ] => [ "phenomenes" ], [ 98, 250_000 ] => [ "intouchables", "phenomenes" ],
    [ 96, 50_000 ] => [], [ 98, 1_000 ] => [], [ 70, 20_000 ] => [], [ 39, 20_000 ] => [], [ 85, 199_999 ] => [], [ 99, nil ] => []
  }.each do |(rating, review_count), expected|
    test "a card at #{rating} % and #{review_count.inspect} reviews is in the hall of fame sets #{expected.inspect}" do
      assert_equal expected, hall_of_fame_keys(rating, review_count)
    end
  end

  test "the hall of fame sets follow their fixed order, members by release date, tiered like a theme" do
    rows = [
      row(4, rating: 50, review_count: 300_000, release_date: Date.new(2015, 1, 1)),
      row(3, rating: 99, review_count: 500, release_date: Date.new(2010, 1, 1)),
      row(2, rating: 97, review_count: 210_000, release_date: Date.new(2012, 1, 1)),
      row(1, rating: 98, review_count: 30_000, release_date: Date.new(2012, 1, 1))
    ]

    assert_equal [
      { kind: "hall_of_fame", key: "intouchables", params: { "hall_of_fame" => "intouchables" }, members: ids(1, 2),
        tiers: { "bronze" => 1, "silver" => 1, "gold" => 1, "complete" => 2 } },
      { kind: "hall_of_fame", key: "pepites", params: { "hall_of_fame" => "pepites" }, members: ids(3),
        tiers: { "bronze" => 1, "silver" => 1, "gold" => 1, "complete" => 1 } },
      { kind: "hall_of_fame", key: "mal-aimes", params: { "hall_of_fame" => "mal-aimes" }, members: ids(4),
        tiers: { "bronze" => 1, "silver" => 1, "gold" => 1, "complete" => 1 } },
      { kind: "hall_of_fame", key: "phenomenes", params: { "hall_of_fame" => "phenomenes" }, members: ids(2, 4),
        tiers: { "bronze" => 1, "silver" => 1, "gold" => 1, "complete" => 2 } }
    ], Catalog::SetBuilder.hall_of_fame(rows)
  end

  test "a hall of fame rule no card meets builds no set" do
    rows = [ row(1, rating: 98, review_count: 30_000), row(2, rating: 99, review_count: 10), row(3, rating: 50, review_count: 40_000) ]

    assert_equal %w[intouchables pepites mal-aimes], Catalog::SetBuilder.hall_of_fame(rows).map { |set| set[:key] }
  end

  test "a hall of fame set of 30 cards needs 3, 8 and 15 of them for bronze, silver and gold, and 30 to complete" do
    rows = (1..30).map { |id| row(id, rating: 60, review_count: 25_000) }

    assert_equal({ "bronze" => 3, "silver" => 8, "gold" => 15, "complete" => 30 }, Catalog::SetBuilder.hall_of_fame(rows).sole[:tiers])
  end

  test "every hall of fame key is a well-formed set key" do
    assert_equal %w[intouchables pepites mal-aimes phenomenes], Catalog::HallOfFame.keys
    assert Catalog::HallOfFame.keys.all? { |key| Catalog::Set::KEY_FORMAT.match?(key) }
  end

  test "a hall of fame card of no theme stays in the UFOs" do
    rows = [ row(1, rating: 99, review_count: 300_000) ]

    assert_equal ids(1), Catalog::SetBuilder.ufos(rows).sole[:members]
  end

  # All kinds

  test "a publication builds the theme sets, the franchises, the studios, the hall of fame, then the UFOs, every card in at least one" do
    rows = [ row(1, genres: %w[roguelike deckbuilder horror]), row(2, rating: 99, review_count: 200), row(3, genres: %w[rpg]) ] +
      franchise_rows("Halo", [ "Halo 3", "Halo Wars", "Halo Infinite" ], first: 4, developers: [ "Bungie" ], review_count: 90_000)

    sets = Catalog::SetBuilder.call(rows)

    assert_equal [ [ "theme", "roguelike" ], [ "theme", "deckbuilder" ], [ "theme", "horror" ], [ "theme", "rpg" ], [ "franchise", "halo" ],
      [ "studio", "bungie" ], [ "hall_of_fame", "pepites" ], [ "ufo", "ufos" ] ], sets.map { |set| [ set[:kind], set[:key] ] }
    assert_equal ids(1, 2, 3, 4, 5, 6), sets.flat_map { |set| set[:members] }.uniq.sort
  end

  test "a card of a franchise or a studio but of no theme stays in the UFOs" do
    rows = franchise_rows("Halo", [ "Halo 3", "Halo Wars", "Halo Infinite" ], developers: [ "Bungie" ], review_count: 90_000)

    assert_equal ids(1, 2, 3), Catalog::SetBuilder.ufos(rows).sole[:members]
  end

  test "15,000 rows build quickly, every card in a set and every key well-formed" do
    themes = Catalog::Themes.keys
    rows = (1..15_000).map do |id|
      genres = id % 25 == 0 ? [] : [ themes[id % themes.size], themes[(id * 7) % themes.size] ].uniq
      row(id, genres:, prestige_score: (id * 7_919 % 15_000).to_f, release_date: Date.new(1990 + id % 36, 1 + id % 12, 1),
        title: "Series #{id % 500} Episode #{id}", franchises: id.even? ? [ "Series #{id % 500}" ] : [],
        developers: [ "Studio #{id % 1_000} Co., Ltd.", "Porter (Mac)" ], publisher: "Publisher #{id % 300}", review_count: id * 3)
    end

    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    sets = Catalog::SetBuilder.call(rows)
    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started

    assert_operator elapsed, :<, 5
    by_kind = sets.group_by { |set| set[:kind] }
    assert_equal 42, by_kind["theme"].size
    assert_equal 250, by_kind["franchise"].size
    assert_equal 1_000, by_kind["studio"].size
    assert_equal 600, by_kind["ufo"].sole[:members].size
    assert_equal rows.map(&:id).sort, sets.flat_map { |set| set[:members] }.uniq.sort
    assert sets.all? { |set| Catalog::Set::KEY_FORMAT.match?(set[:key]) }
    assert_equal sets.size, sets.map { |set| [ set[:kind], set[:key] ] }.uniq.size
  end
end
