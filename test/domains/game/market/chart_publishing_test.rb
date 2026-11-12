require "test_helper"

class Game::Market::ChartPublishingTest < ActiveSupport::TestCase
  setup do
    Game::Market::ChartPublication.delete_all
    @administrator = accounts_players(:administrator)
  end

  def publish(kind = "reactor", player: @administrator) = Game::Market::PublishChart.new.call(player:, kind:)

  def unpublish(kind = "reactor", player: @administrator) = Game::Market::UnpublishChart.new.call(player:, kind:)

  def events(type) = Rails.configuration.event_store.read.stream(Game::Market::ChartPublishing::STREAM).of_type(type).to_a

  def event_count = Rails.configuration.event_store.read.stream(Game::Market::ChartPublishing::STREAM).count

  test "an administrator publishes a chart, recorded with the time and the administrator, and one ChartPublished event" do
    publication = publish.value!

    assert publication.published?
    assert_not_nil publication.published_at
    assert_equal @administrator.id, publication.changed_by_id
    assert_equal [ { kind: "reactor", player_id: @administrator.id } ], events(Game::Market::ChartPublished).last(1).map(&:data)
    assert_equal [ "reactor" ], Game::Market::ChartPublications.published_kinds
  end

  test "publishing a published chart changes nothing and publishes nothing" do
    published_at = publish.value!.published_at

    assert_no_difference(-> { event_count }) { publish.value! }
    assert_equal published_at, Game::Market::ChartPublication.find_by!(kind: "reactor").published_at
  end

  test "unpublishing records the time and publishes one ChartUnpublished event" do
    publish

    publication = unpublish.value!

    assert_not publication.published?
    assert_not_nil publication.unpublished_at
    assert_equal [ "reactor" ], events(Game::Market::ChartUnpublished).last(1).map { it.data[:kind] }
    assert_empty Game::Market::ChartPublications.published_kinds
  end

  test "unpublishing an unpublished or never published chart changes nothing and publishes nothing" do
    assert_no_difference([ -> { event_count }, -> { Game::Market::ChartPublication.count } ]) { assert unpublish.success? }

    publish
    unpublish
    assert_no_difference(-> { event_count }) { unpublish.value! }
  end

  test "a chart published again after its unpublication is published" do
    publish
    unpublish

    assert publish.value!.published?
  end

  test "only an administrator publishes or unpublishes, and only a known chart" do
    assert_equal :administrator_required, publish(player: accounts_players(:moderator)).failure
    assert_equal :administrator_required, unpublish(player: accounts_players(:player)).failure
    assert_equal :administrator_required, publish(player: nil).failure
    assert_equal :unknown_chart, publish("volume").failure
    assert_equal 0, Game::Market::ChartPublication.count
  end

  test "players and visitors see the published kinds, staff every kind" do
    publish("edition_sales")

    assert_equal [ "edition_sales" ], Game::Market::ChartPublications.visible_kinds(nil)
    assert_equal [ "edition_sales" ], Game::Market::ChartPublications.visible_kinds(accounts_players(:player))
    assert_equal %w[reactor rarity_prices edition_sales], Game::Market::ChartPublications.visible_kinds(accounts_players(:moderator))
  end

  test "each switch says whether its chart is public and since when" do
    publish("rarity_prices")

    switches = Game::Market::ChartPublications.switches.index_by(&:kind)

    assert_equal %w[reactor rarity_prices edition_sales], switches.keys
    assert switches["rarity_prices"].published
    assert_not_nil switches["rarity_prices"].published_at
    assert_not switches["reactor"].published
    assert_nil switches["reactor"].published_at
  end
end
