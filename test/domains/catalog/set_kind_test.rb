require "test_helper"
require_relative "../../support/catalog_seeds"

class Catalog::SetKindTest < ActiveSupport::TestCase
  include CatalogSeeds

  test "the kinds are the sets' kinds, in their tab order" do
    assert_equal Catalog::Set.kinds.keys, Catalog::SetKind::ALL
  end

  test "the pattern matches each kind whole and refuses a retired kind" do
    whole = /\A(?:#{Catalog::SetKind::PATTERN})\z/

    Catalog::SetKind::ALL.each { |kind| assert_match whole, kind }
    assert_no_match whole, "tome"
    assert_no_match whole, "themes"
  end

  test "the order sorts the sets by kind in the tab order" do
    season = seed_published_sets(Catalog::SetKind::ALL.reverse.map { |kind| [ kind, "#{kind}-set", {} ] })

    assert_equal Catalog::SetKind::ALL, Catalog::Set.where(season_id: season.id).order(Catalog::SetKind::ORDER).pluck(:kind)
  end
end
