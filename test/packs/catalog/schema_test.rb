require "test_helper"
require Rails.root.join("db/migrate/20261006100000_remove_dust_tier_from_catalog_card_seasons").to_s

# The catalog's database constraints and model rules (AD-5): what the
# database refuses even when a model is bypassed.
class Catalog::SchemaTest < ActiveSupport::TestCase
  def refused(error = ActiveRecord::StatementInvalid, &block)
    assert_raises(error) { ActiveRecord::Base.transaction(requires_new: true, &block) }
  end

  def card_season
    catalog_card_seasons(:portal_one)
  end

  def draft
    Catalog::Season.create!(status: :draft, number: 2)
  end

  test "rarity tiers are defined once, as keys" do
    assert_equal({ 1 => :common, 2 => :uncommon, 3 => :rare, 4 => :epic, 5 => :legendary }, Catalog::Rarity::TIERS)
    assert_equal %w[en fr], Catalog::CardText::LOCALES
    assert_predicate card_season, :rarity_epic?
  end

  [ 0, 6 ].each do |rarity|
    test "the database refuses a rarity of #{rarity}" do
      refused(ActiveRecord::CheckViolation) { Catalog::CardSeason.where(id: card_season.id).update_all(rarity: rarity) }
    end
  end

  # Whether catalog_card_seasons has the dust_tier column, and its check.
  def dust_tier
    connection = ActiveRecord::Base.connection
    [ connection.column_exists?(:catalog_card_seasons, :dust_tier),
      connection.check_constraint_exists?(:catalog_card_seasons, name: "catalog_card_seasons_dust_tier_check") ]
  end

  test "a card-season has no dust tier, nor its check" do
    assert_equal [ false, false ], dust_tier
  end

  # PostgreSQL DDL is transactional: the round trip is rolled back with the
  # test. The writes are SQL strings, and the model forgets the column after.
  test "the dust tier's removal rolls back to a nullable smallint checked 0 to 4, and runs again" do
    migration = RemoveDustTierFromCatalogCardSeasons.new
    migration.suppress_messages { migration.migrate(:down) }

    assert_equal [ true, true ], dust_tier
    column = ActiveRecord::Base.connection.columns(:catalog_card_seasons).find { |c| c.name == "dust_tier" }
    assert_equal [ :integer, 2, true ], [ column.type, column.limit, column.null ]
    refused(ActiveRecord::CheckViolation) { Catalog::CardSeason.where(id: card_season.id).update_all("dust_tier = 5") }
    assert_equal 1, Catalog::CardSeason.where(id: card_season.id).update_all("dust_tier = 4")

    migration.suppress_messages { migration.migrate(:up) }

    assert_equal [ false, false ], dust_tier
  ensure
    Catalog::CardSeason.reset_column_information
  end

  [ -0.01, 100.01 ].each do |rating|
    test "the database refuses a rating of #{rating}" do
      refused(ActiveRecord::CheckViolation) { Catalog::CardSeason.where(id: card_season.id).update_all(rating: rating) }
    end
  end

  test "the database refuses a review count below 1, and a card-season may have none" do
    refused(ActiveRecord::CheckViolation) { Catalog::CardSeason.where(id: card_season.id).update_all(review_count: 0) }
    assert_equal 1, Catalog::CardSeason.where(id: card_season.id).update_all(review_count: 1)
    assert_equal 1, Catalog::CardSeason.where(id: card_season.id).update_all(review_count: nil)
  end

  test "the model refuses a review count below 1 or fractional" do
    [ 0, 1.5 ].each do |count|
      card_season.review_count = count
      card_season.validate

      assert_predicate card_season.errors[:review_count], :present?, count
    end
    card_season.review_count = 1
    card_season.validate
    assert_empty card_season.errors[:review_count]
  end

  test "a card-season's review count is frozen once its season is published" do
    card_season.review_count = 10

    assert_not card_season.valid?
    assert_includes card_season.errors.details[:base], { error: :frozen_once_published }
  end

  test "rarity and number may stay NULL, scores may not" do
    Catalog::CardSeason.where(id: card_season.id).update_all(rarity: nil, number: nil)

    refused(ActiveRecord::NotNullViolation) { Catalog::CardSeason.where(id: card_season.id).update_all(rating: nil) }
    refused(ActiveRecord::NotNullViolation) { Catalog::CardSeason.where(id: card_season.id).update_all(prestige_score: nil) }
  end

  test "the database refuses a locale other than en and fr" do
    refused(ActiveRecord::CheckViolation) { Catalog::CardText.where(id: catalog_card_texts(:portal_fr).id).update_all(locale: "de") }
  end

  test "the database refuses a second text in the same locale" do
    refused(ActiveRecord::RecordNotUnique) { Catalog::CardText.create!(card: catalog_cards(:portal), locale: "en", title: "Again") }
  end

  test "the database refuses a second draft" do
    draft

    refused(ActiveRecord::RecordNotUnique) { Catalog::Season.create!(status: :draft, number: 3) }
  end

  test "the database refuses a season number twice" do
    refused(ActiveRecord::RecordNotUnique) { Catalog::Season.create!(status: :published, number: 1) }
  end

  test "the database refuses an unknown season status and set kind" do
    refused(ActiveRecord::CheckViolation) { Catalog::Season.where(id: catalog_seasons(:one).id).update_all(status: "archived") }
    refused(ActiveRecord::CheckViolation) { Catalog::Set.where(id: catalog_sets(:valve_one).id).update_all(kind: "tag") }
  end

  test "the database takes every set kind, and the model knows them all, in their tab order" do
    kinds = %w[theme franchise studio hall_of_fame ufo]
    assert_equal kinds, Catalog::Set.kinds.keys

    season_id = catalog_seasons(:one).id
    assert_equal kinds.size, Catalog::Set.insert_all!(kinds.map { |kind| { season_id:, kind:, key: "any" } }).length
  end

  test "the database refuses the kinds no publication builds any more" do
    season_id = catalog_seasons(:one).id

    %w[tome publisher best_of_year].each do |kind|
      refused(ActiveRecord::CheckViolation) { Catalog::Set.insert_all!([ { season_id:, kind:, key: "any" } ]) }
    end
  end

  def set_tier(**attributes)
    { set_id: catalog_sets(:valve_one).id, tier: "complete", required: 1 }.merge(attributes)
  end

  test "the database takes a set's four tiers once each, with a positive requirement" do
    assert_equal 4, Catalog::SetTier.insert_all!(%w[bronze silver gold complete].map { |tier| set_tier(tier:) }).length

    refused(ActiveRecord::RecordNotUnique) { Catalog::SetTier.insert_all!([ set_tier(tier: "gold", required: 9) ]) }
  end

  test "the database refuses an unknown tier, a requirement below 1, and a tier of no set" do
    refused(ActiveRecord::CheckViolation) { Catalog::SetTier.insert_all!([ set_tier(tier: "platinum") ]) }
    refused(ActiveRecord::CheckViolation) { Catalog::SetTier.insert_all!([ set_tier(required: 0) ]) }
    refused(ActiveRecord::NotNullViolation) { Catalog::SetTier.insert_all!([ set_tier(required: nil) ]) }
    refused(ActiveRecord::InvalidForeignKey) { Catalog::SetTier.insert_all!([ set_tier(set_id: -1) ]) }
  end

  test "the model refuses an unknown tier or a requirement that is not a positive integer" do
    draft_set = Catalog::Set.create!(season: draft, kind: "theme", key: "rpg", params: { "theme" => "rpg" })
    assert Catalog::SetTier.new(set: draft_set, tier: "bronze", required: 3).valid?

    [ { tier: "platinum" }, { required: 0 }, { required: 1.5 } ].each do |attributes|
      assert_not Catalog::SetTier.new(set: draft_set, tier: "bronze", required: 3, **attributes).valid?, attributes
    end
  end

  test "a card-season's main theme may stay NULL and is frozen once its season is published" do
    assert_nil card_season.main_theme
    card_season.main_theme = "puzzle"

    assert_not card_season.valid?
    assert_includes card_season.errors.details[:base], { error: :frozen_once_published }
  end

  test "the database refuses a set key twice in a season and kind, but not across kinds" do
    season_id = catalog_seasons(:one).id
    refused(ActiveRecord::RecordNotUnique) { Catalog::Set.insert_all!([ { season_id:, kind: "studio", key: "valve" } ]) }

    assert Catalog::Set.insert_all!([ { season_id:, kind: "franchise", key: "valve" } ])
  end

  test "the database refuses a card-season twice for the same card and season" do
    refused(ActiveRecord::RecordNotUnique) do
      Catalog::CardSeason.insert_all!([ { card_id: catalog_cards(:portal).id, season_id: catalog_seasons(:one).id, prestige_score: 1, rating: 1 } ])
    end
  end

  [ 0, -1 ].each do |number|
    test "the database refuses a card number of #{number}" do
      refused(ActiveRecord::CheckViolation) { Catalog::CardSeason.where(id: card_season.id).update_all(number:) }
    end
  end

  test "the database refuses a card number twice in a season, but not across seasons nor while unnumbered" do
    refused(ActiveRecord::RecordNotUnique) do
      Catalog::CardSeason.where(id: catalog_card_seasons(:common_card_one).id).update_all(number: card_season.number)
    end

    Catalog::CardSeason.where(id: catalog_card_seasons(:common_card_one, :rare_card_one).map(&:id)).update_all(number: nil)
    other = Catalog::CardSeason.create!(card: catalog_cards(:portal), season: draft, prestige_score: 1, rating: 1)
    assert Catalog::CardSeason.where(id: other.id).update_all(number: card_season.number)
  end

  test "the database refuses a card twice for the same source key or slug" do
    card = catalog_cards(:portal)
    attributes = card.attributes.slice("release_date", "image_url", "store_url")

    refused(ActiveRecord::RecordNotUnique) { Catalog::Card.insert_all!([ attributes.merge("source_key" => card.source_key, "slug" => "other") ]) }
    refused(ActiveRecord::RecordNotUnique) { Catalog::Card.insert_all!([ attributes.merge("source_key" => "other", "slug" => card.slug) ]) }
  end

  test "genres and tags default to empty lists, never NULL" do
    card = catalog_cards(:portal)
    Catalog::Card.insert_all!([ card.attributes.slice("release_date", "image_url", "store_url").merge("source_key" => "bare", "slug" => "bare") ])

    bare = Catalog::Card.find_by!(source_key: "bare")
    assert_equal [], bare.genres
    assert_equal [], bare.tags
    refused(ActiveRecord::NotNullViolation) { Catalog::Card.where(id: card.id).update_all(genres: nil) }
  end

  test "developers and franchises default to empty lists, never NULL" do
    card = catalog_cards(:portal)

    assert_equal [ [], [] ], [ card.developers, card.franchises ]
    refused(ActiveRecord::NotNullViolation) { Catalog::Card.where(id: card.id).update_all(developers: nil) }
    refused(ActiveRecord::NotNullViolation) { Catalog::Card.where(id: card.id).update_all(franchises: nil) }
  end

  test "a set key is URL-safe" do
    set = Catalog::Set.new(season: draft, kind: :franchise, key: "Half Life 2")

    assert_not set.valid?
    set.key = "half-life-2"
    assert_predicate set, :valid?
    set.key = "Foo_Bar Studio".parameterize
    assert_equal "foo_bar-studio", set.key
    assert_predicate set, :valid?
  end

  test "a membership's card-season and set share a season" do
    set = Catalog::Set.create!(season: draft, kind: :theme, key: "action")
    membership = Catalog::SetMembership.new(set: set, card_season: card_season, position: 1)

    assert_not membership.valid?
    assert_includes membership.errors.details[:card_season], { error: :other_season }
  end

  test "a card-season's season data is frozen once its season is published" do
    card_season.rarity = :legendary

    assert_not card_season.valid?
    assert_includes card_season.errors.details[:base], { error: :frozen_once_published }

    card_season.reload.number = 99
    assert_not card_season.valid?
    assert_includes card_season.errors.details[:base], { error: :frozen_once_published }
  end

  test "no card-season is added to a published season" do
    other = Catalog::Card.create!(source_key: "src:9", release_date: Date.new(2020, 1, 1), image_url: "https://i.test/9", store_url: "https://s.test/9",
      texts: [ Catalog::CardText.new(locale: "en", title: "Nine"), Catalog::CardText.new(locale: "fr", title: "Neuf") ])
    card_season = Catalog::CardSeason.new(card: other, season: catalog_seasons(:one), prestige_score: 1, rating: 50)

    assert_not card_season.valid?
    assert_includes card_season.errors.details[:base], { error: :frozen_once_published }
  end

  test "a card-season never moves to another card or season" do
    assert_raises(ActiveRecord::ReadonlyAttributeError) { card_season.season_id = draft.id }
    assert_raises(ActiveRecord::ReadonlyAttributeError) { card_season.card_id = card_season.card_id + 1 }
  end

  test "a set never moves to another season, and a membership never moves to another set or card-season" do
    set = catalog_sets(:valve_one)
    membership = Catalog::SetMembership.where(set: set).first!

    assert_raises(ActiveRecord::ReadonlyAttributeError) { set.season_id = draft.id }
    assert_raises(ActiveRecord::ReadonlyAttributeError) { membership.set_id = set.id + 1 }
    assert_raises(ActiveRecord::ReadonlyAttributeError) { membership.card_season_id = membership.card_season_id + 1 }
  end

  test "a card-season of a published season is never destroyed" do
    Catalog::SetMembership.where(card_season: card_season).delete_all

    assert_not card_season.destroy
    assert_includes card_season.errors.details[:base], { error: :frozen_once_published }
    assert Catalog::CardSeason.exists?(card_season.id)
  end

  test "a membership of a published season is never destroyed" do
    membership = catalog_set_memberships(:portal_valve_one)

    assert_not membership.destroy
    assert Catalog::SetMembership.exists?(membership.id)
  end

  test "a card-season's scores follow the source while its season is a draft" do
    draft_card_season = Catalog::CardSeason.create!(card: catalog_cards(:portal), season: draft, prestige_score: 1, rating: 50)

    assert draft_card_season.update(rating: 60, prestige_score: 2)
  end

  test "a set of a published season is frozen" do
    set = catalog_sets(:valve_one)

    assert_not set.update(key: "valve-2")
    assert_includes set.errors.details[:base], { error: :frozen_once_published }
    assert_not set.update(params: { "studio" => "Other" })
    assert_not Catalog::Set.new(season: catalog_seasons(:one), kind: :theme, key: "action").valid?
  end

  test "a set of a published season is never destroyed" do
    set = catalog_sets(:valve_one)

    assert_not set.destroy
    assert_includes set.errors.details[:base], { error: :frozen_once_published }
    assert Catalog::Set.exists?(set.id)
  end

  test "a set of a draft season can change" do
    set = Catalog::Set.create!(season: draft, kind: :theme, key: "action")

    assert set.update(key: "rpg", params: { "theme" => "rpg" })
    assert set.destroy
  end

  test "params default to an empty object, never NULL" do
    Catalog::Set.insert_all!([ { season_id: draft.id, kind: "theme", key: "action" } ])

    assert_equal({}, Catalog::Set.find_by!(key: "action").params)
    assert_equal({ "studio" => "Valve" }, catalog_sets(:valve_one).params)
    refused(ActiveRecord::NotNullViolation) { Catalog::Set.where(id: catalog_sets(:valve_one).id).update_all(params: nil) }
  end

  test "a membership of a published season is frozen" do
    membership = catalog_set_memberships(:portal_valve_one)
    membership.position = 2

    assert_not membership.valid?
    assert_not Catalog::SetMembership.new(set: catalog_sets(:valve_one), card_season: card_season, position: 3).valid?
  end

  test "the slug never changes" do
    card = catalog_cards(:portal)

    assert_raises(ActiveRecord::ReadonlyAttributeError) { card.slug = "other" }
  end

  test "the published season is the highest-numbered published one" do
    assert_equal catalog_seasons(:one), Catalog::PublishedSeason.call

    later = Catalog::Season.create!(status: :published, number: 3, published_at: Time.current)
    draft

    assert_equal later, Catalog::PublishedSeason.call
  end

  test "there is no draft season and no published season when the catalog is empty" do
    assert_nil Catalog::DraftSeason.call
    Catalog::SetMembership.delete_all
    Catalog::Set.delete_all
    Catalog::CardSeason.delete_all
    Catalog::Season.delete_all

    assert_nil Catalog::PublishedSeason.call
  end
end
