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

  test "the UFOs are named in the locale" do
    assert_equal "Les OVNI", label("ufo", {}, :fr)
    assert_equal "The UFOs", label("ufo", {}, :en)
  end

  test "a card's genre is its main theme's name; an unknown key is humanised" do
    assert_equal "Horreur", I18n.with_locale(:fr) { SetLabel.genre("horror") }
    assert_equal "Third-person shooter", I18n.with_locale(:en) { SetLabel.genre("third_person_shooter") }
    assert_equal "Board game", I18n.with_locale(:fr) { SetLabel.genre("board_game") }
  end

  test "every theme has its name in both locales, and no other key is there" do
    %i[en fr].each do |locale|
      assert_equal Catalog::Themes.keys.sort, I18n.t("catalog.themes", locale:).keys.map(&:to_s).sort, locale
    end
  end

  test "a theme set without theme is refused" do
    assert_raises(ArgumentError) { SetLabel.for(Catalog::Set.new(kind: "theme", key: "k", params: {})) }
  end

  test "a publisher set is named after its publisher, in every locale" do
    assert_equal "Valve", label("publisher", { "publisher" => "Valve" }, :fr)
    assert_equal "Valve", label("publisher", { "publisher" => "Valve" }, :en)
  end

  test "a tome is its genre and volume" do
    assert_equal "Gratuit · Tome 2", label("tome", { "genre" => "free_to_play", "volume" => 2 }, :fr)
    assert_equal "Free to Play · Tome 2", label("tome", { "genre" => "free_to_play", "volume" => 2 }, :en)
    assert_equal "Vidéo 360 · Tome 1", label("tome", { "genre" => "360_video", "volume" => 1 }, :fr)
  end

  test "an unknown genre is its key humanised, in English in every locale" do
    assert_equal "Xyz · Tome 1", label("tome", { "genre" => "xyz", "volume" => 1 }, :fr)
    assert_equal "Board game · Tome 3", label("tome", { "genre" => "board_game", "volume" => 3 }, :en)
  end

  test "a tome without genre, or a set of unknown kind, is refused" do
    assert_raises(ArgumentError) { SetLabel.for(Catalog::Set.new(kind: "tome", key: "k", params: { "volume" => 1 })) }
    set = Catalog::Set.new(key: "k", params: {})
    set.define_singleton_method(:kind) { "nope" }
    assert_raises(ArgumentError) { SetLabel.for(set) }
  end

  test "a best of year names its year" do
    assert_equal "Les mieux notés de 2011", label("best_of_year", { "year" => 2011 }, :fr)
    assert_equal "Best rated of 2011", label("best_of_year", { "year" => 2011 }, :en)
  end

  test "every genre a retired tome may name has its label in both locales" do
    # The store's genres, then the genre tags that followed them: seasons
    # published before themes name their tomes with them.
    store_genres = %w[action adventure casual indie massively_multiplayer racing rpg simulation sports strategy free_to_play
      early_access violent gore nudity sexual_content utilities education design_illustration animation_modeling
      audio_production video_production photo_editing software_training web_publishing game_development accounting
      movie documentary episodic short tutorial 360_video]
    genre_tags = %w[fps platformer metroidvania puzzle horror roguelike souls_like hack_and_slash fighting survival city_builder
      sandbox visual_novel point_and_click card_game third_person_shooter stealth rhythm shoot_em_up arcade]
    genres = (store_genres + genre_tags).uniq

    %i[en fr].each do |locale|
      assert_equal genres.sort, I18n.t("catalog.genres", locale:).keys.map(&:to_s).sort, locale
    end
  end

  def heading(kind, params, years, locale = :en)
    I18n.with_locale(locale) { SetLabel.heading(Catalog::SetSlots::SetRef.new(kind:, key: "k", params:), years) }
  end

  test "a tome's heading adds its cards' release years, one when they are all the same" do
    assert_equal "Aventure · Tome 4 · 2011–2012", heading("tome", { "genre" => "adventure", "volume" => 4 }, [ 2012, 2011, 2012 ], :fr)
    assert_equal "Action · Tome 1 · 2015", heading("tome", { "genre" => "action", "volume" => 1 }, [ 2015, 2015 ])
    assert_equal "Action · Tome 1", heading("tome", { "genre" => "action", "volume" => 1 }, [])
  end

  test "any other set's heading is its name" do
    assert_equal "Best rated of 2015", heading("best_of_year", { "year" => 2015 }, [ 2015 ])
    assert_equal "Valve", heading("publisher", { "publisher" => "Valve" }, [ 2004, 2007 ])
  end
end
