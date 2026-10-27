require "test_helper"

# Catalog::Themes, TagKey and the classification they read: the stored
# themes replace the list that was kept in code.
class Catalog::ThemesTest < ActiveSupport::TestCase
  Row = Data.define(:tags, :genres)

  test "the seeded list holds the forty-three themes, in the order they were listed" do
    keys = Catalog::Themes.keys

    assert_equal 43, keys.size
    assert_equal %w[souls_like metroidvania roguelike deckbuilder], keys.first(4)
    assert_equal "adult", keys.last
    assert keys.all? { |key| Catalog::Set::KEY_FORMAT.match?(key) }
    assert_includes keys, "rpg"
    assert_not_includes keys, "action"
  end

  test "a theme created later comes after the seeded ones" do
    Catalog::CreateTheme.new.call(tag_key: "pixel_graphics", name_en: "Pixel art", name_fr: "Pixel art")

    assert_equal "pixel_graphics", Catalog::Themes.keys.last
  end

  test "a tag key is the English name parameterized with underscores" do
    assert_equal "souls_like", Catalog::TagKey.of("Souls-like")
    assert_equal "co_op", Catalog::TagKey.of("Co-op")
    assert_equal "co_op", Catalog::TagKey.of("Co op")
    assert_equal "football_soccer", Catalog::TagKey.of("Football (Soccer)")
    assert_equal "", Catalog::TagKey.of("???")
  end

  test "the themes of tags follow the tags' order, each once, and skip a tag of no theme" do
    classification = Catalog::Themes.classification

    assert_equal %w[roguelike deckbuilder horror], Catalog::Themes.of(%w[indie roguelite deckbuilding pixel_graphics horror], classification)
    assert_equal %w[rpg roguelike], Catalog::Themes.of(%w[jrpg roguelite action_rpg roguelike], classification)
  end

  test "only the five most-voted tags count" do
    assert_equal %w[puzzle], Catalog::Themes.of(%w[a b c d puzzle horror])
  end

  test "the classification is read in one query however many tags it holds" do
    assert_queries_count(1) { Catalog::Themes.classification }
  end

  test "a tag is classified when it is attached or dismissed, unclassified otherwise" do
    classification = Catalog::Themes.classification

    assert classification.classified?("roguelite")
    assert classification.classified?("indie")
    assert_not classification.classified?("pixel_graphics")
  end

  test "the unclassified tags of rows are counted by the rows carrying them, past the fifth one ignored" do
    rows = [ Row.new(tags: %w[indie pixel_graphics 2d rpg puzzle sixth], genres: []), Row.new(tags: %w[pixel_graphics], genres: []) ]

    assert_equal({ "pixel_graphics" => 2, "2d" => 1 }, Catalog::Themes.classification.unclassified_in(rows))
  end

  test "rows are stale when their genres differ from what their tags give now" do
    classification = Catalog::Themes.classification

    assert_not classification.stale?([ Row.new(tags: %w[roguelite horror], genres: %w[roguelike horror]) ])
    assert classification.stale?([ Row.new(tags: %w[roguelite horror], genres: %w[roguelike]) ])
    assert classification.stale?([ Row.new(tags: %w[pixel_graphics], genres: %w[puzzle]) ])
  end

  test "the UFOs' share is over the limit only above 5 %" do
    assert_not Catalog::Themes.ufo_share_over_limit?(5, 100)
    assert Catalog::Themes.ufo_share_over_limit?(6, 100)
    assert_not Catalog::Themes.ufo_share_over_limit?(0, 0)
  end

  test "the seeded classification is the list that was kept in code" do
    defaults = YAML.load_file(Rails.root.join("db/default_themes.yml"))
    classification = Catalog::Themes.classification

    assert_equal defaults.keys, Catalog::Themes.keys
    defaults.each do |key, theme|
      theme["tags"].each { |tag_key| assert_equal key, classification.theme_by_tag[tag_key], tag_key }
    end
    assert_equal %w[action casual free_to_play indie multiplayer singleplayer], classification.dismissed.to_a.sort
  end
end
