require "test_helper"
require_relative "../../support/catalog_seeds"

class Catalog::LandingSampleCardsTest < ActiveSupport::TestCase
  include CatalogSeeds

  def add_published_card(score, rarity:, prefix:)
    season = catalog_seasons(:one)
    seed_card_seasons([ score ], season:, prefix:, titles: [ prefix.titleize ])
    card_season = Catalog::CardSeason.joins(:card).find_by!(catalog_cards: { slug: "#{prefix}-#{season.number}-0" })
    rate(card_season.id, Catalog::Rarity::TIERS.key(rarity))
    card_season
  end

  test "every rarity from the most common, each the published season's card of that rarity, in the locale asked" do
    samples = Catalog::LandingSampleCards.call(locale: :fr)

    assert_equal %i[common uncommon rare epic legendary], samples.keys
    assert_equal %w[tin-soldier green-hills blue-depths portal golden-crown], samples.values.map(&:id)
    assert_equal %w[common uncommon rare epic legendary], samples.values.map(&:rarity)
    assert_equal "Soldat de plomb", samples.fetch(:common).title
    assert_equal "Tin Soldier", Catalog::LandingSampleCards.call(locale: "en").fetch(:common).title
  end

  test "the card with the higher prestige score of a rarity is shown" do
    add_published_card(0.95, rarity: :epic, prefix: "bright")
    add_published_card(0.5, rarity: :rare, prefix: "dull")

    samples = Catalog::LandingSampleCards.call(locale: :en)

    assert_equal "bright-1-0", samples.fetch(:epic).id
    assert_equal "blue-depths", samples.fetch(:rare).id
  end

  test "two cards of the same score: the first written is shown" do
    add_published_card(0.9, rarity: :epic, prefix: "twin")

    assert_equal "portal", Catalog::LandingSampleCards.call(locale: :en).fetch(:epic).id
  end

  test "a rarity without a card is nil, the others are shown" do
    Catalog::CardSeason.where(id: catalog_card_seasons(:legendary_card_one).id).delete_all

    samples = Catalog::LandingSampleCards.call(locale: :en)

    assert_nil samples.fetch(:legendary)
    assert_equal "portal", samples.fetch(:epic).id
  end

  test "without a published season every rarity is nil" do
    Catalog::Season.update_all(status: "draft", published_at: nil)

    assert_equal Catalog::Rarity::TIERS.values.index_with { nil }, Catalog::LandingSampleCards.call(locale: :en)
  end

  test "a draft season's cards are never shown" do
    seed_card_seasons([ 5.0 ], prefix: "draft")

    assert_not_includes Catalog::LandingSampleCards.call(locale: :en).values.map(&:id), "draft-2-0"
  end

  test "the season, then one query for every rarity and one for their faces" do
    queries = []
    callback = ->(*, payload) { queries << payload[:sql] unless payload[:name] == "SCHEMA" }
    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") { Catalog::LandingSampleCards.call(locale: :en) }

    assert_equal 3, queries.size
  end

  test "cached per published season and locale" do
    with_memory_cache do
      first = Catalog::LandingSampleCards.call(locale: :en)
      Catalog::CardSeason.where(id: catalog_card_seasons(:legendary_card_one).id).delete_all

      assert_equal first, Catalog::LandingSampleCards.call(locale: :en)
      assert_nil Catalog::LandingSampleCards.call(locale: :fr).fetch(:legendary)
    end
  end

  test "a newer published season shows its own cards at once, whatever is cached" do
    with_memory_cache do
      Catalog::LandingSampleCards.call(locale: :en)
      newer = seed_card_seasons([ 1.0 ], prefix: "newer", titles: [ "Newer" ])
      rate(Catalog::CardSeason.where(season_id: newer.id), Catalog::Rarity::TIERS.key(:common))
      newer.update_columns(status: "published", published_at: Time.current)

      samples = Catalog::LandingSampleCards.call(locale: :en)

      assert_equal "newer-2-0", samples.fetch(:common).id
      assert_nil samples.fetch(:legendary)
    end
  end

  def with_memory_cache
    original = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    yield
  ensure
    Rails.cache = original
  end
end
