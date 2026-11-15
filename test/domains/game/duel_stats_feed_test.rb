require "test_helper"
require_relative "../../support/catalog_seeds"
require_relative "../../support/game_packs"

# Each Monday's duel stats run posts once to the feed the cards whose standing moved most since the last weekly
# percentiles: per card its largest single stat change, the three largest rises then the three largest falls. The post has
# no player, so only the whole feed lists it.
class Game::DuelStatsFeedTest < ActiveSupport::TestCase
  include CatalogSeeds
  include GamePacks

  WEDNESDAY = Time.utc(2026, 11, 18, 9)
  MONDAY = Time.utc(2026, 11, 16)

  VALUES = { popularity: 100, rating: 80, release: Date.new(2000, 1, 1), discovery: Time.utc(2026, 1, 1), circulation: 1 }.freeze

  # A published season of rated card-seasons, numbered in card order; returns their ids.
  def published_card_seasons(count, **seeds)
    season = seed_card_seasons(distinct_scores(count), **seeds)
    season.update!(status: :published, published_at: 1.day.ago)
    ids = Catalog::CardSeason.where(season_id: season.id).order(:id).ids
    ids.each_with_index { |id, index| Catalog::CardSeason.where(id:).update_all(rarity: 1, number: index + 1) }
    ids
  end

  # A duel row whose given stats went from their last weekly percentile to their current one: `stats` is { stat => [ from, to ] }.
  def duel_row(card_season_id, **stats)
    columns = Game::DuelStat::STATS.flat_map do |stat|
      from, to = stats[stat]
      [ [ :"#{stat}_value", (VALUES.fetch(stat) unless to.nil?) ], [ :"#{stat}_percentile", to ],
        [ :"#{stat}_median_distance", (0.0 unless to.nil?) ], [ :"#{stat}_weekly_percentile", from ] ]
    end
    Game::DuelStat.insert_all!([ { card_season_id:, **columns.to_h, trump_stat: "popularity", trump_direction: "high", computed_at: WEDNESDAY } ])
  end

  def duel_event(reason = "weekly", at: WEDNESDAY) = Game::DuelStatsComputed.new(data: { reason: }, metadata: { timestamp: at })

  def handle(reason = "weekly", at: WEDNESDAY) = Game::Handlers::DuelStatsFeed.call(duel_event(reason, at:))

  def compute(reason) = Game::ComputeDuelStats.new.call(reason:).value!

  def posts = Game::FeedEntry.where(kind: "duel_stats")

  def moves = posts.sole.moves.map { it.values_at("card_season_id", "stat", "from", "to") }

  # A second edition of the card of `card_season_id`, in a new season.
  def second_edition(card_season_id)
    card_id = Catalog::CardSeason.where(id: card_season_id).pick(:card_id)
    season = Catalog::Season.create!(status: :draft, number: Catalog::Season.next_number)
    Catalog::CardSeason.insert_all!([ { card_id:, season_id: season.id, prestige_score: 1.0, rating: 80.0, review_count: 5_000, rarity: 1, number: 1 } ],
      returning: :id).rows.flatten.first
  end

  def duel_post_row(**columns)
    { kind: "duel_stats", moves: [], notable: true, occurred_at: MONDAY, created_at: MONDAY, updated_at: MONDAY, **columns }
  end

  test "a weekly run posts its week's Monday, with no player, the three largest rises then the three largest falls" do
    ids = published_card_seasons(8)
    [ 5.0, 30.0, 12.5, 1.0, -2.0, -40.0, -7.5, -20.0 ].each_with_index { |change, index| duel_row(ids[index], popularity: [ 50.0, 50.0 + change ]) }

    handle

    post = posts.sole
    assert_nil post.player_id
    assert_equal MONDAY, post.occurred_at
    assert post.notable
    assert_equal [ [ ids[1], "popularity", 50.0, 80.0 ], [ ids[2], "popularity", 50.0, 62.5 ], [ ids[0], "popularity", 50.0, 55.0 ],
      [ ids[5], "popularity", 50.0, 10.0 ], [ ids[7], "popularity", 50.0, 30.0 ], [ ids[6], "popularity", 50.0, 42.5 ] ], moves
  end

  test "a card is placed by its largest single stat: a larger fall makes it a fall" do
    card, = published_card_seasons(1)
    duel_row(card, popularity: [ 50.0, 53.0 ], rating: [ 60.0, 52.0 ])

    handle

    assert_equal [ [ card, "rating", 60.0, 52.0 ] ], moves
  end

  test "equal changes go to the earlier stat, then to the lower card-season, and equal moves list by card-season" do
    first, second, third = published_card_seasons(3)
    duel_row(third, popularity: [ 40.0, 50.0 ])
    duel_row(second, rating: [ 40.0, 50.0 ], release: [ 60.0, 70.0 ])
    duel_row(first, discovery: [ 20.0, 30.0 ], popularity: [ 70.0, 60.0 ])

    handle

    assert_equal [ [ second, "rating", 40.0, 50.0 ], [ third, "popularity", 40.0, 50.0 ], [ first, "popularity", 70.0, 60.0 ] ], moves
  end

  test "a card's editions make one move, the largest of them" do
    card, = published_card_seasons(1)
    edition = second_edition(card)
    duel_row(card, popularity: [ 50.0, 55.0 ])
    duel_row(edition, circulation: [ 20.0, 32.0 ])

    handle

    assert_equal [ [ edition, "circulation", 20.0, 32.0 ] ], moves
  end

  test "a stat with no last weekly or no current percentile is no move" do
    card, other = published_card_seasons(2)
    duel_row(card, discovery: [ nil, 40.0 ], popularity: [ 50.0, 51.0 ])
    duel_row(other, circulation: [ 30.0, nil ])

    handle

    assert_equal [ [ card, "popularity", 50.0, 51.0 ] ], moves
  end

  test "nothing moved, no post" do
    card, = published_card_seasons(1)
    duel_row(card, popularity: [ 50.0, 50.0 ], rating: [ 40.0, 40.0 ])

    handle

    assert_empty posts
  end

  test "fewer moves than six make a shorter post" do
    first, second = published_card_seasons(2)
    duel_row(first, popularity: [ 10.0, 20.0 ])
    duel_row(second, popularity: [ 10.0, 30.0 ])

    handle

    assert_equal [ second, first ], moves.map(&:first)
  end

  test "one post a week, left as it is by a later run; the next week has its own" do
    card, = published_card_seasons(1)
    duel_row(card, popularity: [ 50.0, 60.0 ])
    handle
    Game::DuelStat.where(card_season_id: card).update_all(popularity_percentile: 90.0)

    handle(at: WEDNESDAY + 2.days)

    assert_equal [ [ card, "popularity", 50.0, 60.0 ] ], moves

    handle(at: WEDNESDAY + 1.week)

    assert_equal [ MONDAY, MONDAY + 1.week ], posts.order(:occurred_at).pluck(:occurred_at)
  end

  test "a first or season run posts nothing" do
    card, = published_card_seasons(1)
    duel_row(card, popularity: [ 50.0, 60.0 ])

    handle("first")
    handle("season")

    assert_empty posts
  end

  test "the first Monday compares with the deploy's first run, inside the run's transaction" do
    ids = published_card_seasons(4, review_counts: [ 10, 20, 30, 40 ])
    compute("first")
    assert_empty posts
    ids.zip([ 40, 30, 20, 10 ]).each { |id, review_count| Catalog::CardSeason.where(id:).update_all(review_count:) }

    travel_to(WEDNESDAY) { compute("weekly") }

    assert_equal [ [ ids[0], "popularity", 12.5, 87.5 ], [ ids[1], "popularity", 37.5, 62.5 ],
      [ ids[3], "popularity", 87.5, 12.5 ], [ ids[2], "popularity", 62.5, 37.5 ] ], moves
    assert_equal MONDAY, posts.sole.occurred_at
  end

  test "a season run after a catalog change posts nothing" do
    ids = published_card_seasons(2, review_counts: [ 10, 20 ])
    compute("first")
    ids.zip([ 20, 10 ]).each { |id, review_count| Catalog::CardSeason.where(id:).update_all(review_count:) }

    compute("season")

    assert_empty posts
  end

  test "the database refuses a post with a player or without moves, and any other entry without a player" do
    player = accounts_players(:player)
    card_season_id = catalog_card_seasons(:portal_one).id

    pack_id = create_pack(player).id

    [ duel_post_row(player_id: player.id), duel_post_row(moves: nil), duel_post_row(card_season_id:, rarity: 4),
      { kind: "pull", pack_id:, position: 0, card_season_id:, rarity: 4, notable: true, occurred_at: MONDAY, created_at: MONDAY, updated_at: MONDAY },
      { kind: "repost", card_season_id:, rarity: 4, notable: true, occurred_at: MONDAY, created_at: MONDAY, updated_at: MONDAY },
      { kind: "verdict", notable: true, occurred_at: MONDAY, created_at: MONDAY, updated_at: MONDAY } ].each do |row|
      assert_raises(ActiveRecord::StatementInvalid, row.inspect) { Game::FeedEntry.transaction(requires_new: true) { Game::FeedEntry.insert_all!([ row ]) } }
    end
    assert_empty Game::FeedEntry.where(player_id: nil)
  end

  test "the whole feed lists the post to a visitor and a player, on its page, on newer pages and by its token" do
    card, = published_card_seasons(1)
    duel_row(card, popularity: [ 50.0, 60.0 ])
    handle
    post = posts.sole
    player = accounts_players(:player)

    [ nil, player ].each do |viewer|
      assert_includes Game::FeedEntries.call(viewer).map(&:entry), post
      assert_includes Game::FeedEntries.page(viewer, from: Game::FeedEntries.position(post)).items.map(&:entry), post
      assert_includes Game::FeedEntries.newer(viewer, before: [ MONDAY - 1.day, 0 ]).items.map(&:entry), post
      assert_equal post, Game::VisibleFeedEntry.call(viewer, post.token)
    end
    item = Game::FeedEntries.call(player).find { it.entry == post }
    assert_nil item.player
    assert_nil item.player_title
  end

  test "a player's friends and a kind never list the post" do
    card, = published_card_seasons(1)
    duel_row(card, popularity: [ 50.0, 60.0 ])
    handle
    player = accounts_players(:player)

    assert_empty Game::FeedEntries.call(player, players: [ player.id, accounts_players(:moderator).id ]).select { it.entry.kind == "duel_stats" }
    Game::FeedEntry::KINDS.excluding("duel_stats").each do |kind|
      assert_empty Game::FeedEntries.call(nil, kind:).select { it.entry.kind == "duel_stats" }, kind
    end
    assert_empty LiveStream.ticker_items.select { |item, *| item.entry.kind == "duel_stats" }
  end
end
