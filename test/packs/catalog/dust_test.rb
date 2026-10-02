require "test_helper"

# Catalog::Dust (DESIGN.md, Dust): the level from the game's age on the
# publication date.
class Catalog::DustTest < ActiveSupport::TestCase
  PUBLISHED_ON = Date.new(2026, 10, 2)

  {
    "2026-04-02" => :none, "2025-10-02" => :light, "2025-10-03" => :none,
    "2021-10-03" => :light, "2021-10-02" => :marked, "2016-10-02" => :thick,
    "2006-10-03" => :thick, "2006-10-02" => :buried, "1996-01-01" => :buried,
    "2027-01-01" => :none
  }.each do |released, level|
    test "a game released on #{released} and published on 2026-10-02 has #{level} dust" do
      assert_equal level, Catalog::Dust::LEVELS.fetch(Catalog::Dust.level_for(Date.parse(released), on: PUBLISHED_ON))
    end
  end

  test "a release after the publication counts as age 0" do
    assert_equal 0, Catalog::Dust.age(Date.new(2030, 1, 1), on: PUBLISHED_ON)
  end

  test "a 29 February release has its anniversary on 1 March in common years" do
    released = Date.new(2024, 2, 29)

    assert_equal 0, Catalog::Dust.age(released, on: Date.new(2025, 2, 28))
    assert_equal 1, Catalog::Dust.age(released, on: Date.new(2025, 3, 1))
    assert_equal 4, Catalog::Dust.age(released, on: Date.new(2028, 2, 29))
    assert_equal 3, Catalog::Dust.age(released, on: Date.new(2028, 2, 28))
  end
end
