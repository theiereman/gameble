require "test_helper"

# Catalog::CreateTheme, RenameTheme, AttachTag and DismissTags: the
# administrators curate the themes and the classification of Steam tags;
# each success publishes one event, each refusal writes nothing.
class Catalog::ThemeOperationsTest < ActiveSupport::TestCase
  def events = Rails.configuration.event_store.read.stream(Catalog::Theme.stream_name).to_a

  def rows = [ Catalog::Theme, Catalog::TagClassification ].map { |model| model.order(:id).pluck(Arel.sql("md5(#{model.table_name}::text)")) }

  def classification_of(tag_key) = Catalog::TagClassification.find_by(tag_key:)

  test "a theme is created from a tag, named in both languages, and the tag is attached to it" do
    theme = Catalog::CreateTheme.new.call(tag_key: "pixel_graphics", name_en: "  Pixel   art ", name_fr: "Pixel art").value!

    assert_equal [ "pixel_graphics", "Pixel art", "Pixel art" ], theme.slice(:key, :name_en, :name_fr).values
    assert_equal 24, theme.token.size
    assert_equal theme, classification_of("pixel_graphics").theme
    assert_not classification_of("pixel_graphics").not_a_theme
    assert_equal [ Catalog::ThemeCreated ], events.map(&:class)
    assert_equal({ theme_id: theme.id, tag_key: "pixel_graphics" }, events.last.data)
  end

  test "a tag already classified is moved to the new theme" do
    theme = Catalog::CreateTheme.new.call(tag_key: "roguelite", name_en: "Roguelite", name_fr: "Roguelite").value!

    assert_equal theme, classification_of("roguelite").theme
    assert_equal "roguelite", theme.key
    assert_equal 1, Catalog::TagClassification.where(tag_key: "roguelite").count
  end

  test "a key another theme has is followed by a number" do
    first = Catalog::CreateTheme.new.call(tag_key: "rpg", name_en: "Role", name_fr: "Rôle").value!
    second = Catalog::CreateTheme.new.call(tag_key: "rpg", name_en: "Role 2", name_fr: "Rôle 2").value!

    assert_equal %w[rpg_2 rpg_3], [ first.key, second.key ]
  end

  test "a theme needs a name in each language, 60 characters at most" do
    before = rows
    [ { name_en: "", name_fr: "Pixel" }, { name_en: "Pixel", name_fr: "  " }, { name_en: nil, name_fr: "Pixel" }, { name_en: "Pixel", name_fr: 12 },
      { name_en: "x" * 61, name_fr: "Pixel" } ].each do |names|
      assert_equal :invalid_theme_name, Catalog::CreateTheme.new.call(tag_key: "pixel_graphics", **names).failure, names.inspect
    end

    assert_equal before, rows
    assert_empty events
  end

  test "a tag key that is no key is refused" do
    before = rows
    [ nil, "", "Pixel Graphics", "pixel-graphics", 12 ].each do |tag_key|
      assert_equal :invalid_tag, Catalog::CreateTheme.new.call(tag_key:, name_en: "Pixel", name_fr: "Pixel").failure, tag_key.inspect
    end

    assert_equal before, rows
  end

  test "a theme is renamed in both languages, its key and tags kept, with one event" do
    theme = catalog_themes(:roguelike)

    assert Catalog::RenameTheme.new.call(theme:, name_en: " Rogue-like ", name_fr: "Rogue-like FR").success?

    theme.reload
    assert_equal [ "roguelike", "Rogue-like", "Rogue-like FR" ], theme.slice(:key, :name_en, :name_fr).values
    assert_equal theme, classification_of("roguelite").theme
    assert_equal [ Catalog::ThemeRenamed ], events.map(&:class)
    assert_equal({ theme_id: theme.id }, events.last.data)
  end

  test "a blank rename is refused and writes nothing" do
    before = rows

    assert_equal :invalid_theme_name, Catalog::RenameTheme.new.call(theme: catalog_themes(:roguelike), name_en: "", name_fr: "x").failure
    assert_equal before, rows
    assert_empty events
  end

  test "an unclassified tag is attached to a theme, with one event" do
    theme = catalog_themes(:roguelike)

    assert Catalog::AttachTag.new.call(tag_key: "pixel_graphics", theme:).success?

    assert_equal theme, classification_of("pixel_graphics").theme
    assert_equal [ Catalog::TagAttached ], events.map(&:class)
    assert_equal({ theme_id: theme.id, tag_key: "pixel_graphics" }, events.last.data)
  end

  test "a dismissed tag attached to a theme is a theme's tag, and a theme's tag moves to another theme" do
    Catalog::AttachTag.new.call(tag_key: "indie", theme: catalog_themes(:horror))
    Catalog::AttachTag.new.call(tag_key: "roguelite", theme: catalog_themes(:horror))

    assert_equal [ catalog_themes(:horror), catalog_themes(:horror) ], [ classification_of("indie").theme, classification_of("roguelite").theme ]
    assert_not classification_of("indie").not_a_theme
  end

  test "attaching a tag that is no key is refused" do
    before = rows

    assert_equal :invalid_tag, Catalog::AttachTag.new.call(tag_key: "No Key", theme: catalog_themes(:horror)).failure
    assert_equal before, rows
  end

  test "tags are dismissed as no theme, one or many, with one event each call" do
    assert Catalog::DismissTags.new.call(tag_keys: %w[pixel_graphics 2d pixel_graphics]).success?
    assert Catalog::DismissTags.new.call(tag_keys: %w[roguelite]).success?

    assert_equal [ true, true, true ], %w[pixel_graphics 2d roguelite].map { classification_of(it).not_a_theme }
    assert_nil classification_of("roguelite").theme
    assert_equal [ Catalog::TagsDismissed ] * 2, events.map(&:class)
    assert_equal({ tag_keys: %w[pixel_graphics 2d] }, events.first.data)
  end

  test "dismissing no tag, or a tag that is no key, is refused" do
    before = rows

    [ [], nil, "indie", [ "indie", "Not A Key" ], [ 3 ] ].each do |tag_keys|
      assert_equal :invalid_tag, Catalog::DismissTags.new.call(tag_keys:).failure, tag_keys.inspect
    end
    assert_equal before, rows
    assert_empty events
  end

  test "every failure code of the themes has a message in both locales" do
    %i[en fr].each do |locale|
      I18n.with_locale(locale) do
        %i[invalid_tag invalid_theme_name].each do |code|
          assert_not_includes Catalog::CreateTheme.failure_message(code), "Translation missing", "#{code} #{locale}"
        end
      end
    end
  end

  test "a classification change leaves the draft's cards as they are until they are rescored" do
    season = Catalog::Season.create!(status: :draft, number: Catalog::Season.next_number)
    card = catalog_cards(:portal)
    card.update_columns(tags: %w[pixel_graphics], genres: [])
    Catalog::CardSeason.create!(card:, season:, prestige_score: 1, rating: 80)

    Catalog::AttachTag.new.call(tag_key: "pixel_graphics", theme: catalog_themes(:horror))

    assert_equal [], card.reload.genres
    assert Catalog::DraftRescoreNeeded.call
  end
end
