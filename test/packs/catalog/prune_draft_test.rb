require "test_helper"
require_relative "../../support/catalog_seeds"

# Catalog::PruneDraft (story 2.11): the draft keeps only the given cards; a
# published season, the cards and their texts are never touched.
class Catalog::PruneDraftTest < ActiveSupport::TestCase
  include CatalogSeeds

  def prune(keys)
    Catalog::PruneDraft.new.call(keep_source_keys: keys)
  end

  def events_of(season)
    Rails.configuration.event_store.read.stream(Catalog::Season.stream_name(season.id)).to_a
  end

  def draft_keys(season)
    Catalog::CardSeason.where(season:).joins(:card).order("catalog_cards.source_key").pluck("catalog_cards.source_key")
  end

  test "the draft keeps only the cards named; the others' card-seasons go, their cards and texts stay" do
    draft = seed_card_seasons([ 3.0, 2.0, 1.0 ])
    counts = [ Catalog::Card.count, Catalog::CardText.count ]

    result = prune([ "test:seed-2-0", "test:seed-2-2", "test:unknown" ])

    assert_equal 1, result.value!
    assert_equal [ "test:seed-2-0", "test:seed-2-2" ], draft_keys(draft)
    assert_equal counts, [ Catalog::Card.count, Catalog::CardText.count ]
    assert_equal [ Catalog::DraftPruned ], events_of(draft).map(&:class)
    assert_equal({ season_id: draft.id, removed: 1 }, events_of(draft).last.data)
  end

  test "a published season's card-seasons, sets and memberships are never touched" do
    published = publish_sets_draft
    before = [ Catalog::CardSeason.where(season: published).order(:id).pluck(:id, :rarity, :prestige_score),
      Catalog::Set.where(season: published).count, Catalog::SetMembership.count ]
    draft = seed_card_seasons([ 2.0, 1.0 ], prefix: "next")

    assert_equal 2, prune([]).value!

    assert_empty draft_keys(draft)
    assert_equal before, [ Catalog::CardSeason.where(season: published).order(:id).pluck(:id, :rarity, :prestige_score),
      Catalog::Set.where(season: published).count, Catalog::SetMembership.count ]
    assert_predicate draft.reload, :draft?
  end

  test "keeping every card removes nothing and still publishes the event" do
    draft = seed_card_seasons([ 2.0, 1.0 ])

    assert_equal 0, prune([ "test:seed-2-0", "test:seed-2-1" ]).value!

    assert_equal 2, draft_keys(draft).size
    assert_equal({ season_id: draft.id, removed: 0 }, events_of(draft).sole.data)
  end

  test "with no draft it removes nothing and publishes no event" do
    assert_no_difference(-> { Catalog::CardSeason.count }) do
      assert_equal 0, prune([ "test:x" ]).value!
    end
    assert_empty Rails.configuration.event_store.read.of_type(Catalog::DraftPruned).to_a
  end

  test "keys with quotes, commas and backslashes are matched as given" do
    draft = Catalog::Season.create!(status: :draft, number: Catalog::Season.next_number)
    keys = [ "a\"b", "c,d", "e\\f", "{g}", "NULL" ]
    keys.each_with_index do |key, index|
      Catalog::UpsertDraftCard.new.call(source_key: key, release_date: Date.new(2011, 1, 1), image_url: "https://i.example.test/#{index}.jpg",
        store_url: "https://s.example.test/#{index}", texts: { "en" => { title: "T #{index}" }, "fr" => { title: "T #{index}" } },
        prestige_score: 0.5, rating: 50).value!
    end

    assert_equal 1, prune(keys - [ "c,d" ]).value!

    assert_equal (keys - [ "c,d" ]).sort, draft_keys(draft).sort
  end

  test "twenty thousand keys travel as one array, the draft locked FOR SHARE" do
    draft = seed_card_seasons([ 2.0, 1.0 ])
    keys = Array.new(20_000) { |index| "steam:#{index}" } + [ "test:seed-2-1" ]
    statements = []
    subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") { |*, payload| statements << payload }

    begin
      assert_equal 1, prune(keys).value!
    ensure
      ActiveSupport::Notifications.unsubscribe(subscriber)
    end

    assert_equal [ "test:seed-2-1" ], draft_keys(draft)
    assert statements.any? { |payload| payload[:sql].include?("FOR SHARE") }, "the draft is locked FOR SHARE"
    delete = statements.find { |payload| payload[:sql].start_with?("DELETE") }
    assert_includes delete[:sql], "ANY("
    assert_operator delete[:binds].size, :<=, 2, "the season and the array, never one bind per key"
  end
end
