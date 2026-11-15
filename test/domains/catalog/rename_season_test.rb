require "test_helper"

# Catalog::RenameSeason: a published season takes a new name in both
# languages, with one event; a draft, an unknown number or a bad name
# writes nothing.
class Catalog::RenameSeasonTest < ActiveSupport::TestCase
  def season = catalog_seasons(:one)

  def events = Rails.configuration.event_store.read.stream(Catalog::Season.stream_name(season.id)).to_a

  def rename(number: season.number, name_en: "Winter", name_fr: "Hiver")
    Catalog::RenameSeason.new.call(number:, name_en:, name_fr:)
  end

  test "a published season without a name is named in both languages, squished, with one event" do
    assert_nil season.name(:fr)

    result = rename(name_en: " Deep  winter ", name_fr: "Hiver")

    assert_equal season, result.value!
    assert_equal [ "Deep winter", "Hiver" ], season.reload.slice(:name_en, :name_fr).values
    assert_equal [ "Hiver", "Deep winter", "Deep winter" ], [ season.name(:fr), season.name(:en), season.name("en") ]
    assert_equal [ Catalog::SeasonRenamed ], events.map(&:class)
    assert_equal({ season_id: season.id }, events.last.data)
  end

  test "a named season is renamed" do
    rename
    rename(name_en: "Spring", name_fr: "Printemps")

    assert_equal [ "Spring", "Printemps" ], season.reload.slice(:name_en, :name_fr).values
    assert_equal 2, events.size
  end

  test "a bad name is invalid_season_name and writes nothing" do
    before = season.attributes
    [ { name_en: "", name_fr: "Hiver" }, { name_en: "Winter", name_fr: " " }, { name_en: nil, name_fr: "Hiver" }, { name_en: "Winter", name_fr: [ "Hiver" ] },
      { name_en: "Winter", name_fr: "x" * 61 } ].each do |names|
      assert_equal :invalid_season_name, rename(**names).failure, names.inspect
    end

    assert_equal before, season.reload.attributes
    assert_empty events
  end

  test "a draft or an unknown number is no_published_season and writes nothing" do
    season.update_columns(status: "draft", published_at: nil)

    assert_equal :no_published_season, rename.failure
    assert_equal :no_published_season, rename(number: 99).failure
    assert_nil season.reload.name_en
    assert_empty events
  end

  test "every failure code of the rename has a message in both locales" do
    %i[en fr].each do |locale|
      I18n.with_locale(locale) do
        %i[invalid_season_name no_published_season].each do |code|
          assert_not_includes Catalog::RenameSeason.failure_message(code), "Translation missing", "#{code} #{locale}"
        end
      end
    end
  end
end
