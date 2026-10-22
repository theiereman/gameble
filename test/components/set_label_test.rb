require "test_helper"

# SetLabel: a set's name from its kind and params, per locale, and a card's
# genre from its main theme.
class SetLabelTest < ActiveSupport::TestCase
  def label(kind, params, locale)
    I18n.with_locale(locale) { SetLabel.for(Catalog::Set.new(kind:, key: "k", params:)) }
  end

  test "a theme set is its theme's name in the locale" do
    assert_equal "Vie à la ferme", label("theme", { "theme" => "farming" }, :fr)
    assert_equal "Farming", label("theme", { "theme" => "farming" }, :en)
    assert_equal "Réalité virtuelle", label("theme", { "theme" => "vr" }, :fr)
  end

  test "a franchise or studio set is named after its franchise or studio, in every locale" do
    assert_equal "Tom Clancy", label("franchise", { "franchise" => "Tom Clancy" }, :fr)
    assert_equal "Tom Clancy", label("franchise", { "franchise" => "Tom Clancy" }, :en)
    assert_equal "CAPCOM", label("studio", { "studio" => "CAPCOM" }, :fr)
    assert_equal "CAPCOM", label("studio", { "studio" => "CAPCOM" }, :en)
  end

  test "a hall of fame set is named in the locale" do
    assert_equal "Les Pépites", label("hall_of_fame", { "hall_of_fame" => "pepites" }, :fr)
    assert_equal "Hidden Gems", label("hall_of_fame", { "hall_of_fame" => "pepites" }, :en)
    assert_equal "Les Mal-aimés", label("hall_of_fame", { "hall_of_fame" => "mal-aimes" }, :fr)
    assert_equal "The Unloved", label("hall_of_fame", { "hall_of_fame" => "mal-aimes" }, :en)
  end

  test "every hall of fame set has its name in both locales, and no other key is there" do
    %i[en fr].each do |locale|
      assert_equal Catalog::HallOfFame.keys.sort, I18n.t("catalog.hall_of_fame", locale:).keys.map(&:to_s).sort, locale
    end
  end

  test "a hall of fame set without its key is refused" do
    assert_raises(ArgumentError) { SetLabel.for(Catalog::Set.new(kind: "hall_of_fame", key: "k", params: {})) }
  end

  test "the UFOs are named in the locale" do
    assert_equal "Les OVNI", label("ufo", {}, :fr)
    assert_equal "The UFOs", label("ufo", {}, :en)
  end

  test "a card's genre is its main theme's name; an unknown key is humanised" do
    assert_equal "Horreur", I18n.with_locale(:fr) { SetLabel.genre("horror") }
    assert_equal "Third-person shooter", I18n.with_locale(:en) { SetLabel.genre("third_person_shooter") }
    assert_equal "Board game", I18n.with_locale(:fr) { SetLabel.genre("board_game") }
  end

  test "a theme's stored name follows a rename at once, in each locale" do
    Catalog::RenameTheme.new.call(theme: catalog_themes(:horror), name_en: "Scary", name_fr: "Effrayant")

    assert_equal "Effrayant", I18n.with_locale(:fr) { SetLabel.genre("horror") }
    assert_equal "Scary", I18n.with_locale(:en) { SetLabel.genre("horror") }
    assert_equal "Scary", label("theme", { "theme" => "horror" }, :en)
  end

  test "a theme set without theme is refused" do
    assert_raises(ArgumentError) { SetLabel.for(Catalog::Set.new(kind: "theme", key: "k", params: {})) }
  end

  test "a set of unknown kind is refused" do
    set = Catalog::Set.new(key: "k", params: {})
    set.define_singleton_method(:kind) { "nope" }
    assert_raises(ArgumentError) { SetLabel.for(set) }
  end

  test "a set whose params are nil is refused, not a NoMethodError" do
    assert_raises(ArgumentError) { SetLabel.for(Catalog::Set.new(kind: "theme", key: "k", params: nil)) }
    assert_raises(ArgumentError) { SetLabel.for(Catalog::Set.new(kind: "hall_of_fame", key: "k", params: nil)) }
  end
end
