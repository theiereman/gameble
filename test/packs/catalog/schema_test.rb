require "test_helper"

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

  test "rarity tiers and dust levels are defined once, as keys" do
    assert_equal({ 1 => :steel, 2 => :emerald, 3 => :sapphire, 4 => :amethyst, 5 => :gold }, Catalog::Rarity::TIERS)
    assert_equal({ 0 => :none, 1 => :light, 2 => :marked, 3 => :thick, 4 => :buried }, Catalog::Dust::LEVELS)
    assert_equal %w[en fr], Catalog::CardText::LOCALES
    assert_predicate card_season, :rarity_amethyst?
    assert_predicate card_season, :dust_thick?
  end

  [ 0, 6 ].each do |rarity|
    test "the database refuses a rarity of #{rarity}" do
      refused(ActiveRecord::CheckViolation) { Catalog::CardSeason.where(id: card_season.id).update_all(rarity: rarity) }
    end
  end

  [ -1, 5 ].each do |dust_tier|
    test "the database refuses a dust tier of #{dust_tier}" do
      refused(ActiveRecord::CheckViolation) { Catalog::CardSeason.where(id: card_season.id).update_all(dust_tier: dust_tier) }
    end
  end

  [ -0.01, 100.01 ].each do |rating|
    test "the database refuses a rating of #{rating}" do
      refused(ActiveRecord::CheckViolation) { Catalog::CardSeason.where(id: card_season.id).update_all(rating: rating) }
    end
  end

  test "rarity and dust tier may stay NULL, scores may not" do
    Catalog::CardSeason.where(id: card_season.id).update_all(rarity: nil, dust_tier: nil)

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

  test "the database refuses a set key twice in a season and kind, but not across kinds" do
    refused(ActiveRecord::RecordNotUnique) { Catalog::Set.create!(season: catalog_seasons(:one), kind: :publisher, key: "valve") }

    assert Catalog::Set.create!(season: catalog_seasons(:one), kind: :tome, key: "valve")
  end

  test "the database refuses a card-season twice for the same card and season" do
    refused(ActiveRecord::RecordNotUnique) do
      Catalog::CardSeason.insert_all!([ { card_id: catalog_cards(:portal).id, season_id: catalog_seasons(:one).id, prestige_score: 1, rating: 1 } ])
    end
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

  test "a set key is URL-safe" do
    set = Catalog::Set.new(season: catalog_seasons(:one), kind: :tome, key: "Action Vol 1")

    assert_not set.valid?
    set.key = "action-1"
    assert_predicate set, :valid?
    set.key = "Foo_Bar Studio".parameterize
    assert_equal "foo_bar-studio", set.key
    assert_predicate set, :valid?
  end

  test "a membership's card-season and set share a season" do
    set = Catalog::Set.create!(season: draft, kind: :tome, key: "action-1")
    membership = Catalog::SetMembership.new(set: set, card_season: card_season, position: 1)

    assert_not membership.valid?
    assert_includes membership.errors.details[:card_season], { error: :other_season }
  end

  test "a card-season's season data is frozen once its season is published" do
    card_season.rarity = :gold

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
