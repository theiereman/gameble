require "test_helper"

# Steam::GenreTags (catalog-and-rarity.md, Sets): a game's genres are its
# listed genre tags in its tag order, most-voted first.
class Steam::GenreTagsTest < ActiveSupport::TestCase
  test "the listed tags keep the game's order, unlisted ones dropped: the first is the tome" do
    assert_equal %w[puzzle fps], Steam::GenreTags.call([ 492, 1664, 1663 ])
  end

  test "a game without a listed tag has no genre" do
    assert_equal [], Steam::GenreTags.call([ 19, 492 ])
    assert_equal [], Steam::GenreTags.call([])
    assert_equal [], Steam::GenreTags.call(nil)
  end

  test "an unknown tagid is dropped" do
    assert_equal [ "rpg" ], Steam::GenreTags.call([ 999_999, 122 ])
  end

  test "the list holds 25 genres, each a valid set key" do
    assert_equal 25, Steam::GenreTags::GENRES.size
    assert_equal 25, Steam::GenreTags::GENRES.values.uniq.size
    Steam::GenreTags::GENRES.each_value { |genre| assert_match Catalog::Set::KEY_FORMAT, genre }
  end

  test "every genre has a label in both locales" do
    %i[en fr].each do |locale|
      Steam::GenreTags::GENRES.each_value do |genre|
        assert I18n.exists?("catalog.genres.#{genre}", locale), "catalog.genres.#{genre} in #{locale}"
      end
    end
  end
end
