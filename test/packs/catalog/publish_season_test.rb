require "test_helper"
require_relative "../../support/catalog_seeds"

# Catalog::PublishSeason (AD-3, AD-5): publishing the draft, every failure,
# the event, the card numbers (R3) and their one-time backfill, and the
# published-season query the draw reads.
class Catalog::PublishSeasonTest < ActiveSupport::TestCase
  include CatalogSeeds

  def publish(number, random: SecureRandom)
    Catalog::PublishSeason.new(random:).call(number:)
  end

  def events_of(season)
    Rails.configuration.event_store.read.stream(Catalog::Season.stream_name(season.id)).to_a
  end

  def season_data(season)
    Catalog::CardSeason.where(season_id: season.id).order(:id).pluck(:rarity, :number, :updated_at)
  end

  def assert_nothing_written(season, &block)
    before = [ season.reload.attributes, season_data(season), events_of(season).size ]
    block.call
    assert_equal before, [ season.reload.attributes, season_data(season), events_of(season).size ]
  end

  test "publishing a draft of 150 sets rarities, flips the season and publishes one event" do
    season = seed_card_seasons(distinct_scores(150))
    now = Time.utc(2026, 10, 2, 23, 30)

    result = travel_to(now) { publish(season.number) }

    assert result.success?
    assert_equal season, result.value!
    season.reload
    assert_predicate season, :published?
    assert_equal now, season.published_at
    assert_nil Catalog::DraftSeason.call
    assert_equal season, Catalog::PublishedSeason.call

    card_seasons = Catalog::CardSeason.where(season_id: season.id)
    assert_equal({ "legendary" => 2, "epic" => 6, "rare" => 15, "uncommon" => 37, "common" => 90 }, card_seasons.group(:rarity).count)
    top = card_seasons.max_by(&:prestige_score)
    assert_equal "legendary", top.rarity
    assert_equal "common", card_seasons.min_by(&:prestige_score).rarity

    events = events_of(season)
    assert_equal [ Catalog::SeasonPublished ], events.map(&:class)
    assert_equal({ season_id: season.id }, events.first.data)
  end

  def sets_of(season)
    Catalog::Set.where(season_id: season.id).includes(memberships: { card_season: :card }).order(:kind, :key)
  end

  def member_rows(set)
    set.memberships.sort_by(&:position).map(&:card_season)
  end

  test "publishing builds the season's publisher sets, tomes and best-of-years, members in order" do
    season = seed_sets_draft

    assert publish(season.number).success?

    sets = sets_of(season).group_by(&:kind)
    assert_equal({ "publisher" => 1, "tome" => 4, "best_of_year" => 3 }, sets.transform_values(&:size))

    publisher = sets["publisher"].sole
    assert_equal [ "p", { "publisher" => "P" } ], [ publisher.key, publisher.params ]
    assert_equal 5, publisher.memberships.size

    tomes = sets["tome"].sort_by { |set| [ set.params["genre"], set.params["volume"] ] }
    assert_equal %w[action-1 action-2 action-3 rpg-1], tomes.map(&:key)
    assert_equal [ 25, 25, 25, 44 ], tomes.map { |set| set.memberships.size }
    assert_equal({ "genre" => "action", "volume" => 2, "volumes" => 3 }, tomes[1].params)

    best = sets["best_of_year"].sort_by(&:key)
    assert_equal [ [ "2011", 10 ], [ "2012", 9 ], [ "2015", 10 ] ], best.map { |set| [ set.key, set.memberships.size ] }
    assert_equal [ { "year" => 2011 }, { "year" => 2012 }, { "year" => 2015 } ], best.map(&:params)

    sets.values.flatten.each do |set|
      assert_equal (1..set.memberships.size).to_a, set.memberships.map(&:position).sort, set.key
    end
    (sets["publisher"] + tomes).each do |set|
      cards = member_rows(set).map(&:card)
      assert_equal cards.sort_by { |card| [ card.release_date, card.id ] }, cards, set.key
    end
    best.each do |set|
      ranked = member_rows(set)
      assert_equal ranked.sort_by { |cs| [ -cs.rating, -cs.prestige_score, cs.card_id ] }, ranked, set.key
    end
    action = Catalog::CardSeason.where(season_id: season.id).joins(:card).where("catalog_cards.genres[1] = 'action'").ids.sort
    assert_equal action, tomes.first(3).flat_map { |set| set.memberships.map(&:card_season_id) }.sort
  end

  test "a draft that yields no publisher set and no tome still publishes, with its years' best" do
    season = seed_card_seasons(distinct_scores(21), release_dates: Array.new(21) { |i| Date.new(2010 + i % 2, 1, 1) })

    assert publish(season.number).success?

    assert_predicate season.reload, :published?
    assert_equal [ [ "best_of_year", "2010" ], [ "best_of_year", "2011" ] ], sets_of(season).map { |set| [ set.kind, set.key ] }
  end

  test "a set key outside KEY_FORMAT raises and nothing is published" do
    season = seed_card_seasons(distinct_scores(21), genres: Array.new(21) { [ "Free To Play" ] })

    assert_nothing_written(season) do
      assert_raises(ArgumentError) { publish(season.number) }
    end
    assert_predicate season.reload, :draft?
    assert_equal 0, Catalog::Set.where(season_id: season.id).count
  end

  test "the sets of a published season are frozen" do
    season = seed_sets_draft
    publish(season.number)

    set = Catalog::Set.find_by!(season_id: season.id, kind: :tome, key: "rpg-1")
    assert_not set.update(key: "rpg-2")
    assert_not set.destroy
    assert_not set.memberships.first.destroy
  end

  test "a published season's data is frozen" do
    season = seed_card_seasons(distinct_scores(21))
    publish(season.number)

    card_season = Catalog::CardSeason.find_by!(season_id: season.id, rarity: :legendary)
    assert_not card_season.update(rarity: :common)
  end

  def numbers_of(season)
    Catalog::CardSeason.where(season_id: season.id).order(:id).pluck(:number)
  end

  test "publishing gives every card-season a distinct number in 1..n" do
    season = seed_card_seasons(distinct_scores(150))

    assert publish(season.number).success?

    assert_equal (1..150).to_a, numbers_of(season).sort
  end

  test "the numbers are a shuffle of 1..n over the card-seasons in id order, by the random given" do
    season = seed_card_seasons(distinct_scores(21))

    assert publish(season.number, random: Random.new(42)).success?

    expected = (1..21).to_a.shuffle(random: Random.new(42))
    assert_equal expected, numbers_of(season)
    assert_not_equal (1..21).to_a, expected, "the seed shuffles"
  end

  test "a published card-season's number is frozen" do
    season = seed_card_seasons(distinct_scores(21))
    publish(season.number)

    card_season = Catalog::CardSeason.where(season_id: season.id).first
    assert_not card_season.update(number: card_season.number + 100)
    assert card_season.errors.added?(:base, :frozen_once_published)
  end

  # PublishSeason#number_published

  def unnumbered_published_season
    season = seed_card_seasons(distinct_scores(21))
    assert publish(season.number).success?
    Catalog::CardSeason.where(season_id: season.id).update_all(number: nil)
    season.reload
  end

  test "number_published numbers a published season once, by the same shuffle, without an event" do
    season = unnumbered_published_season

    assert_no_difference -> { events_of(season).size } do
      result = Catalog::PublishSeason.new(random: Random.new(7)).number_published(number: season.number)
      assert_equal season, result.value!
    end

    assert_equal (1..21).to_a.shuffle(random: Random.new(7)), numbers_of(season)
  end

  test "number_published on a numbered season is already_numbered and writes nothing" do
    season = unnumbered_published_season
    assert Catalog::PublishSeason.new.number_published(number: season.number).success?

    assert_nothing_written(season) do
      assert_equal :already_numbered, Catalog::PublishSeason.new.number_published(number: season.number).failure
    end
  end

  test "number_published on a draft or an unknown number is no_published_season" do
    season = seed_card_seasons(distinct_scores(21))

    assert_nothing_written(season) do
      assert_equal :no_published_season, Catalog::PublishSeason.new.number_published(number: season.number).failure
      assert_equal :no_published_season, Catalog::PublishSeason.new.number_published(number: 999).failure
    end
    assert_equal Array.new(21), numbers_of(season)
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

  test "a draft scored by one formula publishes, and so does one scored before versions existed" do
    versioned = seed_card_seasons(distinct_scores(21), score_versions: Array.new(21, 2))
    assert publish(versioned.number).success?

    legacy = seed_card_seasons(distinct_scores(21), prefix: "legacy")
    assert_equal [ nil ], Catalog::CardSeason.where(season_id: legacy.id).distinct.pluck(:prestige_score_version)
    assert publish(legacy.number).success?
  end

  {
    "unversioned and versioned scores" => [ nil, 2 ],
    "scores of two versions" => [ 1, 2 ]
  }.each do |label, versions|
    test "a draft mixing #{label} is mixed_score_versions and writes nothing" do
      season = seed_card_seasons(distinct_scores(150), score_versions: Array.new(150) { |index| versions[index % 2] })

      assert_nothing_written(season) { assert_equal :mixed_score_versions, publish(season.number).failure }
      assert_predicate season.reload, :draft?
      assert_empty Catalog::Set.where(season_id: season.id)
    end
  end

  test "a mixed draft publishes once every card is scored again by the current formula" do
    season = seed_card_seasons(distinct_scores(21), score_versions: Array.new(20, 2) + [ 1 ])
    assert_equal :mixed_score_versions, publish(season.number).failure

    Catalog::CardSeason.where(season_id: season.id).find_each do |card_season|
      card = card_season.card
      Catalog::UpsertDraftCard.new.call(
        source_key: card.source_key, release_date: card.release_date, image_url: card.image_url, store_url: card.store_url,
        texts: card.texts.to_h { |text| [ text.locale, { title: text.title } ] },
        prestige_score: card_season.prestige_score, prestige_score_version: 2, rating: card_season.rating.to_f
      ).value!
    end

    assert publish(season.number).success?
  end

  test "every failure code of the publication has a message in both locales" do
    %i[en fr].each do |locale|
      I18n.with_locale(locale) do
        %i[no_draft stale_draft empty_season mixed_score_versions empty_tier].each do |code|
          assert_not_includes Catalog::PublishSeason.failure_message(code), "Translation missing", "#{code} #{locale}"
        end
      end
    end
  end

  test "an upsert after the publication opens the next draft" do
    season = seed_card_seasons(distinct_scores(21))
    publish(season.number)

    card_season = Catalog::UpsertDraftCard.new.call(
      source_key: "test:seed-#{season.number}-0", release_date: Date.new(2000, 1, 1),
      image_url: "https://images.example.test/a.jpg", store_url: "https://store.example.test/a",
      texts: { "en" => { title: "Seed" }, "fr" => { title: "Graine" } }, prestige_score: 1.0, prestige_score_version: 2, rating: 50.0
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
    assert_equal ids.where(rarity: :legendary).ids, result[:tiers][5]
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
