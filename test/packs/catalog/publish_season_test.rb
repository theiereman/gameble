require "test_helper"
require_relative "../../support/catalog_seeds"

# Catalog::PublishSeason (AD-3, AD-5): publishing the draft, every failure,
# the event, and the published-season query the draw reads.
class Catalog::PublishSeasonTest < ActiveSupport::TestCase
  include CatalogSeeds

  def publish(number)
    Catalog::PublishSeason.new.call(number:)
  end

  def events_of(season)
    Rails.configuration.event_store.read.stream(Catalog::Season.stream_name(season.id)).to_a
  end

  def season_data(season)
    Catalog::CardSeason.where(season_id: season.id).order(:id).pluck(:rarity, :dust_tier, :updated_at)
  end

  def assert_nothing_written(season, &block)
    before = [ season.reload.attributes, season_data(season), events_of(season).size ]
    block.call
    assert_equal before, [ season.reload.attributes, season_data(season), events_of(season).size ]
  end

  test "publishing a draft of 150 sets rarities and dust, flips the season and publishes one event" do
    release_dates = Array.new(150) { |index| index.even? ? Date.new(2006, 10, 2) : Date.new(2025, 10, 3) }
    season = seed_card_seasons(distinct_scores(150), release_dates:)
    now = Time.utc(2026, 10, 2, 23, 30)

    result = travel_to(now) { publish(season.number) }

    assert result.success?
    assert_equal season, result.value!
    season.reload
    assert_predicate season, :published?
    assert_equal now, season.published_at
    assert_nil Catalog::DraftSeason.call
    assert_equal season, Catalog::PublishedSeason.call

    card_seasons = Catalog::CardSeason.where(season_id: season.id).includes(:card)
    assert_equal({ "gold" => 2, "amethyst" => 6, "sapphire" => 15, "emerald" => 37, "steel" => 90 }, card_seasons.group(:rarity).count)
    top = card_seasons.max_by(&:prestige_score)
    assert_equal "gold", top.rarity
    assert_equal "steel", card_seasons.min_by(&:prestige_score).rarity
    card_seasons.each do |card_season|
      expected = card_season.card.release_date == Date.new(2006, 10, 2) ? "buried" : "none"
      assert_equal expected, card_season.dust_tier
    end

    events = events_of(season)
    assert_equal [ Catalog::SeasonPublished ], events.map(&:class)
    assert_equal({ season_id: season.id }, events.first.data)
  end

  test "the publication date is the UTC date of the publication" do
    season = seed_card_seasons(distinct_scores(21), release_dates: Array.new(21, Date.new(2025, 10, 3)))

    # 2026-10-03 00:30 UTC is still 2026-10-02 in Honolulu (UTC-10): only the
    # UTC date makes the game a year old.
    Time.use_zone("Pacific/Honolulu") do
      travel_to(Time.utc(2026, 10, 3, 0, 30)) do
        assert_equal Date.new(2026, 10, 2), Time.current.to_date
        assert publish(season.number).success?
      end
    end

    assert_equal [ "light" ], Catalog::CardSeason.where(season_id: season.id).distinct.pluck(:dust_tier)
  end

  test "a published season's data is frozen" do
    season = seed_card_seasons(distinct_scores(21))
    publish(season.number)

    card_season = Catalog::CardSeason.find_by!(season_id: season.id, rarity: :gold)
    assert_not card_season.update(rarity: :steel)
  end

  test "no draft is no_draft" do
    assert_nil Catalog::DraftSeason.call

    assert_no_difference -> { Catalog::Season.count } do
      assert_equal :no_draft, publish(1).failure
    end
  end

  test "a second publish is no_draft and changes nothing" do
    season = seed_card_seasons(distinct_scores(21))
    assert publish(season.number).success?

    assert_nothing_written(season) { assert_equal :no_draft, publish(season.number).failure }
  end

  test "a number other than the draft's is stale_draft" do
    season = seed_card_seasons(distinct_scores(21))

    assert_nothing_written(season) do
      assert_equal :stale_draft, publish(season.number + 1).failure
      assert_equal :stale_draft, publish(nil).failure
    end
    assert_predicate season.reload, :draft?
  end

  test "a draft with no card-season is empty_season" do
    season = seed_card_seasons([])

    assert_nothing_written(season) { assert_equal :empty_season, publish(season.number).failure }
  end

  test "a draft of 20 distinct scores is empty_tier" do
    season = seed_card_seasons(distinct_scores(20))

    assert_nothing_written(season) { assert_equal :empty_tier, publish(season.number).failure }
  end

  test "a score covering two cuts is empty_tier" do
    season = seed_card_seasons(Array.new(5, 100.0) + distinct_scores(95))

    assert_nothing_written(season) { assert_equal :empty_tier, publish(season.number).failure }
  end

  test "an upsert after the publication opens the next draft" do
    season = seed_card_seasons(distinct_scores(21))
    publish(season.number)

    card_season = Catalog::UpsertDraftCard.new.call(
      source_key: "test:seed-#{season.number}-0", release_date: Date.new(2000, 1, 1),
      image_url: "https://images.example.test/a.jpg", store_url: "https://store.example.test/a",
      texts: { "en" => { title: "Seed" }, "fr" => { title: "Graine" } }, prestige_score: 1.0, rating: 50.0
    ).value!

    assert_equal season.number + 1, card_season.season.number
    assert_predicate card_season.season, :draft?
    assert_equal 21, Catalog::CardSeason.where(season_id: season.id).count
  end

  # Catalog::PublishedCardSeasonsByTier

  test "the published season's card-seasons by tier, the draft left out" do
    Catalog::SetMembership.delete_all
    Catalog::Set.delete_all
    Catalog::CardSeason.delete_all
    Catalog::Season.delete_all
    one = seed_card_seasons(distinct_scores(21))
    publish(one.number)
    seed_card_seasons(distinct_scores(30), prefix: "draft")

    result = Catalog::PublishedCardSeasonsByTier.call

    ids = Catalog::CardSeason.where(season_id: one.id)
    assert_equal one.id, result[:season_id]
    assert_equal [ 1, 2, 3, 4, 5 ], result[:tiers].keys.sort
    assert_equal({ 1 => 12, 2 => 5, 3 => 2, 4 => 1, 5 => 1 }, result[:tiers].transform_values(&:size))
    assert_equal ids.order(:id).ids, result[:tiers].values.flatten.sort
    assert_equal ids.where(rarity: :gold).ids, result[:tiers][5]
  end

  test "the highest published season is the one drawn from" do
    second = seed_card_seasons(distinct_scores(21))
    publish(second.number)

    assert_equal second.id, Catalog::PublishedCardSeasonsByTier.call[:season_id]
  end

  test "nothing published is nil" do
    Catalog::Season.published.update_all(status: "draft", published_at: nil)

    assert_nil Catalog::PublishedCardSeasonsByTier.call
  end
end
