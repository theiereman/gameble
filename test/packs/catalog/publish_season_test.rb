require "test_helper"
require_relative "../../support/catalog_seeds"

# Catalog::PublishSeason: publishing the draft, every failure, the event,
# the card numbers, main themes, sets and tiers, the numbers' one-time
# backfill, and the published-season query the draw reads.
class Catalog::PublishSeasonTest < ActiveSupport::TestCase
  include CatalogSeeds

  def publish(number, random: SecureRandom)
    Catalog::PublishSeason.new(random:).call(number:)
  end

  def events_of(season)
    Rails.configuration.event_store.read.stream(Catalog::Season.stream_name(season.id)).to_a
  end

  def season_data(season)
    Catalog::CardSeason.where(season_id: season.id).order(:id).pluck(:rarity, :number, :main_theme, :updated_at)
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

  test "publishing builds the season's theme sets and the UFOs, members in order, every card-season in one" do
    season = seed_sets_draft

    assert publish(season.number).success?

    sets = sets_of(season).index_by { |set| [ set.kind, set.key ] }
    expected = { [ "theme", "roguelike" ] => 119, [ "theme", "rpg" ] => 44, [ "theme", "horror" ] => 16, [ "theme", "pirates" ] => 8,
      [ "ufo", "ufos" ] => 15 }
    assert_equal expected, sets.transform_values { |set| set.memberships.size }
    assert_equal({ "theme" => "roguelike" }, sets[[ "theme", "roguelike" ]].params)
    assert_equal({}, sets[[ "ufo", "ufos" ]].params)

    sets.each_value do |set|
      assert_equal (1..set.memberships.size).to_a, set.memberships.map(&:position).sort, set.key
      cards = member_rows(set).map(&:card)
      assert_equal cards.sort_by { |card| [ card.release_date, card.id ] }, cards, set.key
    end
    card_seasons = Catalog::CardSeason.where(season_id: season.id)
    assert_empty card_seasons.where.not(id: Catalog::SetMembership.select(:card_season_id))
    themeless = card_seasons.joins(:card).where("cardinality(catalog_cards.genres) = 0").ids.sort
    assert_equal themeless, sets[[ "ufo", "ufos" ]].memberships.map(&:card_season_id).sort
  end

  test "publishing writes each set's tiers by its size, the UFOs' as a theme's" do
    season = seed_sets_draft

    assert publish(season.number).success?

    tiers = Catalog::SetTier.joins(:set).where(catalog_sets: { season_id: season.id }).pluck("catalog_sets.key", :tier, :required)
      .group_by(&:first).transform_values { |rows| rows.to_h { |_, tier, required| [ tier, required ] } }
    assert_equal({
      "roguelike" => { "apprentice" => 12, "adept" => 30, "expert" => 60, "master" => 90, "complete" => 119 },
      "rpg" => { "adept" => 11, "expert" => 22, "master" => 33, "complete" => 44 },
      "horror" => { "expert" => 6, "master" => 11, "complete" => 16 },
      "pirates" => { "master" => 4, "complete" => 8 },
      "ufos" => { "expert" => 5, "master" => 10, "complete" => 15 }
    }, tiers)
  end

  test "publishing builds the franchise and studio sets, members in release order, each tiered by its size" do
    season = seed_franchises_and_studios_draft

    assert publish(season.number).success?

    sets = sets_of(season).index_by { |set| [ set.kind, set.key ] }
    assert_equal [ [ "franchise", "tom-clancy" ], [ "studio", "capcom" ], [ "theme", "rpg" ], [ "ufo", "ufos" ] ], sets.keys
    assert_equal({ "franchise" => "Tom Clancy" }, sets[[ "franchise", "tom-clancy" ]].params)
    assert_equal({ "studio" => "CAPCOM" }, sets[[ "studio", "capcom" ]].params)
    assert_equal [ "Tom Clancy's Rainbow Six", "Tom Clancy's The Division", "Tom Clancy's Ghost Recon" ],
      member_rows(sets[[ "franchise", "tom-clancy" ]]).map { |card_season| card_season.card.text("en").title }
    assert_equal [ [ "CAPCOM Co., Ltd." ], [ "CAPCOM Co., Ltd." ], [ "Capcom" ] ],
      member_rows(sets[[ "studio", "capcom" ]]).map { |card_season| card_season.card.developers }

    tiers = Catalog::SetTier.joins(:set).where(catalog_sets: { season_id: season.id, kind: %w[franchise studio] })
      .pluck("catalog_sets.kind", :tier, :required)
    assert_equal [ [ "franchise", "complete", 3 ], [ "studio", "complete", 3 ] ], tiers.sort
  end

  test "publishing builds the hall of fame sets, members in release order, each tiered by its size" do
    season = seed_hall_of_fame_draft

    assert publish(season.number).success?

    sets = sets_of(season).where(kind: "hall_of_fame").index_by(&:key)
    titles = sets.transform_values { |set| member_rows(set).map { |card_season| card_season.card.text("en").title } }
    assert_equal({ "intouchables" => [ "Seed 0", "Seed 5" ], "pepites" => [ "Seed 1" ], "mal-aimes" => [ "Seed 2", "Seed 3" ],
      "phenomenes" => [ "Seed 4", "Seed 5" ] }, titles)
    assert_equal({ "hall_of_fame" => "mal-aimes" }, sets["mal-aimes"].params)

    tiers = Catalog::SetTier.joins(:set).where(catalog_sets: { season_id: season.id, kind: "hall_of_fame" })
      .pluck("catalog_sets.key", :tier, :required).group_by(&:first).transform_values { |rows| rows.to_h { |_, tier, required| [ tier, required ] } }
    assert_equal({
      "intouchables" => { "complete" => 2 },
      "pepites" => { "complete" => 1 },
      "mal-aimes" => { "complete" => 2 },
      "phenomenes" => { "complete" => 2 }
    }, tiers)
  end

  test "a theme of 7 cards gets master at 4 and complete at 7" do
    season = seed_card_seasons(distinct_scores(21), genres: Array.new(21) { |index| index < 7 ? [ "pirates" ] : [ "rpg" ] })

    assert publish(season.number).success?

    pirates = Catalog::Set.find_by!(season_id: season.id, kind: "theme", key: "pirates")
    assert_equal [ [ "master", 4 ], [ "complete", 7 ] ], pirates.tiers.order(:required, :tier).pluck(:tier, :required)
  end

  test "sets of 3, 7, 12, 40, 100 and 250 cards get exactly the table's tiers" do
    sizes = { "pirates" => 3, "zombies" => 7, "space" => 12, "cyberpunk" => 40, "fps" => 100, "rpg" => 250 }
    season = seed_card_seasons(distinct_scores(sizes.values.sum), genres: sizes.flat_map { |theme, size| Array.new(size) { [ theme ] } })

    assert publish(season.number).success?

    tiers = Catalog::SetTier.joins(:set).where(catalog_sets: { season_id: season.id }).order(:required).pluck("catalog_sets.key", :tier, :required)
      .group_by(&:first).transform_values { |rows| rows.to_h { |_, tier, required| [ tier, required ] } }
    assert_equal({
      "pirates" => { "complete" => 3 },
      "zombies" => { "master" => 4, "complete" => 7 },
      "space" => { "expert" => 4, "master" => 8, "complete" => 12 },
      "cyberpunk" => { "adept" => 10, "expert" => 20, "master" => 30, "complete" => 40 },
      "fps" => { "apprentice" => 10, "adept" => 25, "expert" => 50, "master" => 75, "complete" => 100 },
      "rpg" => { "novice" => 25, "apprentice" => 63, "adept" => 125, "expert" => 188, "master" => 225, "complete" => 250 }
    }, tiers)
  end

  test "publishing gives each card-season its first genre as main theme, none without genre" do
    season = seed_sets_draft

    assert publish(season.number).success?

    main_themes = Catalog::CardSeason.where(season_id: season.id).joins(:card).pluck(:main_theme, "catalog_cards.genres")
    assert main_themes.all? { |main_theme, genres| main_theme == genres.first }
    assert_equal({ "roguelike" => 75, "rpg" => 44, "horror" => 16, nil => 15 }, main_themes.map(&:first).tally)
  end

  test "a draft whose every card has a theme publishes without UFOs" do
    season = seed_card_seasons(distinct_scores(21), genres: Array.new(21) { [ "rpg" ] })

    assert publish(season.number).success?

    assert_equal [ [ "theme", "rpg" ] ], sets_of(season).map { |set| [ set.kind, set.key ] }
  end

  test "a draft holding a card whose genre is no theme is unfilled_sources and writes nothing" do
    season = seed_card_seasons(distinct_scores(21), genres: Array.new(21) { |index| index.zero? ? [ "rpg", "action" ] : [ "rpg" ] })

    assert_nothing_written(season) { assert_equal :unfilled_sources, publish(season.number).failure }
    assert_predicate season.reload, :draft?
    assert_empty Catalog::Set.where(season_id: season.id)
  end

  test "a draft holding a card with no review count, imported before review counts were stored, is unfilled_sources and writes nothing" do
    season = seed_card_seasons(distinct_scores(21), genres: Array.new(21) { [ "rpg" ] }, review_counts: [ nil ] + Array.new(20, 5_000))

    assert_nothing_written(season) { assert_equal :unfilled_sources, publish(season.number).failure }
    assert_predicate season.reload, :draft?
  end

  test "the sets, tiers and main themes of a published season are frozen" do
    season = seed_sets_draft
    publish(season.number)

    set = Catalog::Set.find_by!(season_id: season.id, kind: :theme, key: "rpg")
    assert_not set.update(key: "rpg-2")
    assert_not set.destroy
    assert_not set.memberships.first.destroy
    tier = set.tiers.find_by!(tier: "adept")
    assert_not tier.update(required: 1)
    assert_includes tier.errors.details[:base], { error: :frozen_once_published }
    assert_not tier.destroy
    assert_not Catalog::SetTier.new(set:, tier: "complete", required: 1).valid?
    card_season = Catalog::CardSeason.find_by!(season_id: season.id, main_theme: "rpg")
    assert_not card_season.update(main_theme: "roguelike")
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
        prestige_score: card_season.prestige_score, prestige_score_version: 2, rating: card_season.rating.to_f,
        review_count: card_season.review_count
      ).value!
    end

    assert publish(season.number).success?
  end

  test "every failure code of the publication has a message in both locales" do
    %i[en fr].each do |locale|
      I18n.with_locale(locale) do
        %i[no_draft stale_draft empty_season mixed_score_versions unfilled_sources empty_tier].each do |code|
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
    Catalog::SetTier.delete_all
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
