require "test_helper"
require_relative "../support/catalog_seeds"
require_relative "../support/rake_tasks"

# catalog:number_seasons (the expand step of card numbers): numbers,
# once, each published season whose cards have no number yet, through
# Catalog::PublishSeason#number_published.
class CatalogNumberSeasonsTaskTest < ActiveSupport::TestCase
  include CatalogSeeds
  include RakeTasks

  setup { rake_task("catalog:number_seasons") }

  def run_task
    rake_task("catalog:number_seasons").execute
  end

  def numbers_of(season)
    Catalog::CardSeason.where(season_id: season.id).order(:id).pluck(:number)
  end

  test "numbers the unnumbered published season, reports the numbered one, leaves the draft" do
    one = catalog_seasons(:one)
    before = numbers_of(one)
    two = seed_card_seasons(distinct_scores(21))
    assert Catalog::PublishSeason.new.call(number: two.number).success?
    Catalog::CardSeason.where(season_id: two.id).update_all(number: nil)
    draft = seed_card_seasons(distinct_scores(3))

    output, = capture_io { run_task }

    assert_equal "catalog:number_seasons: season 1 already numbered\ncatalog:number_seasons: season 2 numbered\n", output
    assert_equal before, numbers_of(one)
    assert_equal (1..21).to_a, numbers_of(two).sort
    assert_equal Array.new(3), numbers_of(draft)

    output, = capture_io { run_task }
    assert_equal "catalog:number_seasons: season 1 already numbered\ncatalog:number_seasons: season 2 already numbered\n", output
  end

  test "any other failure aborts with its code" do
    failing = Object.new
    failing.define_singleton_method(:number_published) { |**| Dry::Monads::Result::Failure.new(:no_published_season) }
    Catalog::PublishSeason.singleton_class.define_method(:new) { |*| failing }

    _, error = capture_io { assert_raises(SystemExit) { run_task } }

    assert_equal "catalog:number_seasons: season 1 failed: no_published_season\n", error
  ensure
    Catalog::PublishSeason.singleton_class.remove_method(:new)
  end
end
