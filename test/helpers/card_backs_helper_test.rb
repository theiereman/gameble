require "test_helper"

class CardBacksHelperTest < ActionView::TestCase
  def row(key, state: :unlocked, unlocked_at: nil, seasons: [], tier: nil, week: nil, progress: nil, season: nil)
    back = Game::CardBacks.find(key)
    Game::CardBackShelf::Row.new(back:, state:, season:, seasons:, unlocked_at:, tier:, week:, progress:, group: :base)
  end

  def progress(held, total, required) = Game::SetBackProgress::Progress.new(held:, total:, required:)

  def strip(row) = [ card_back_sentence(row), card_back_tail(row) ]

  def achievement(key) = "#{I18n.t("achievements.names.#{key}")} · #{I18n.t("achievements.conditions.#{key}")}"

  test "Standard is given to every player when they sign up" do
    I18n.with_locale(:fr) do
      assert_equal [ "Offert à tous les joueurs", "à l'inscription" ], strip(row("standard"))
      assert_equal "Standard, actif. Offert à tous les joueurs, à l'inscription.", card_back_label(row("standard", state: :active))
    end
    I18n.with_locale(:en) { assert_equal [ "Given to every player", "when you signed up" ], strip(row("standard")) }
  end

  test "an event back says who it was given to and when, and a past one that it is over" do
    unlocked_at = Time.zone.local(2026, 10, 1, 12)

    I18n.with_locale(:fr) do
      assert_equal [ "Offert aux joueurs de la saison 1", "le 1er octobre 2026" ], strip(row("saison-1", unlocked_at:))
      assert_equal "Offert aux participants des Soldes d'hiver", card_back_sentence(row("soldes-hiver", unlocked_at:))
      assert_equal "Offert aux participants du Millésime 2017", card_back_sentence(row("millesime-2017", unlocked_at:))
      assert_equal [ "Événement terminé", nil ], strip(row("millesime-2017", state: :locked))
      assert_equal "Millésime 2017, verrouillé. Événement terminé.", card_back_label(row("millesime-2017", state: :locked))
    end
    I18n.with_locale(:en) do
      assert_equal [ "Given to the players of season 1", "on October 1, 2026" ], strip(row("saison-1", unlocked_at:))
      assert_equal "Event over", card_back_sentence(row("soldes-hiver", state: :locked))
    end
  end

  test "an achievement back names the achievement and its condition, earned or to earn" do
    unlocked_at = Time.zone.local(2026, 10, 24, 9)

    I18n.with_locale(:fr) do
      centurion = row("centurion", unlocked_at:)
      assert_equal [ "Gagné avec le succès #{achievement(:boosters_100)}", "le 24 octobre 2026" ], strip(centurion)
      assert_equal "Centurion, débloqué. Gagné avec le succès #{achievement(:boosters_100)}, le 24 octobre 2026. Équiper.", card_back_label(centurion)
      assert_equal "Centurion, actif. Gagné avec le succès #{achievement(:boosters_100)}, le 24 octobre 2026.", card_back_label(centurion, state: :active)
      assert_equal "Étoile d'or, verrouillé. Débloquez le succès #{achievement(:first_legendary)}.", card_back_label(row("etoile-dor", state: :locked))
    end
    I18n.with_locale(:en) do
      assert_equal "Earned with the achievement #{achievement(:boosters_100)}", card_back_sentence(row("centurion", unlocked_at:))
      assert_equal "Unlock the achievement #{achievement(:first_legendary)}", card_back_sentence(row("etoile-dor", state: :locked))
    end
  end

  test "the goal back names the week of its mission, or any mission when none is on record" do
    I18n.with_locale(:fr) do
      assert_equal "Gagné en accomplissant la mission de la semaine du 12 octobre", card_back_sentence(row("confrere", week: Date.new(2026, 10, 12)))
      assert_equal "Gagné en accomplissant la mission de la semaine du 1er juin", card_back_sentence(row("confrere", week: Date.new(2026, 6, 1)))
      assert_equal "Gagné en accomplissant une mission de la Confrérie", card_back_sentence(row("confrere"))
      assert_equal "Accomplissez une mission de la Confrérie", card_back_sentence(row("confrere", state: :locked))
    end
    I18n.with_locale(:en) do
      assert_equal "Earned by completing the mission of the week of October 12", card_back_sentence(row("confrere", week: Date.new(2026, 10, 12)))
    end
  end

  test "an earned set back names its tier and the seasons it was earned in" do
    I18n.with_locale(:fr) do
      assert_equal "Gagné au palier Adepte du set Roguelike · saisons 1 et 2", card_back_sentence(row("set-theme-roguelike", tier: "adept", seasons: [ 1, 2 ]))
      assert_equal "Gagné au palier Expert du set Roguelike · saison 1", card_back_sentence(row("set-theme-roguelike", tier: "expert", seasons: [ 1 ]))
      assert_equal "Gagné avec le set Roguelike", card_back_sentence(row("set-theme-roguelike"))
    end
    I18n.with_locale(:en) do
      assert_equal "Earned at the Adept tier of the Roguelike set · seasons 1 and 2", card_back_sentence(row("set-theme-roguelike", tier: "adept", seasons: [ 1, 2 ]))
    end
  end

  test "a locked set back shows how far the player is, or that its set is not in the season" do
    horror = row("set-theme-horror", state: :locked, progress: progress(12, 40, 20))

    I18n.with_locale(:fr) do
      assert_equal [ "Atteignez la moitié du set Horreur", "12 / 40 cartes · plus que 8" ], strip(horror)
      assert_equal "Horreur, verrouillé. Atteignez la moitié du set Horreur, 12 cartes sur 40, plus que 8.", card_back_label(horror)
      assert_equal "Horreur, verrouillé. Atteignez la moitié du set Horreur, 1 carte sur 40, plus que 19.",
        card_back_label(row("set-theme-horror", state: :locked, progress: progress(1, 40, 20)))
      assert_equal "Horreur, verrouillé. Atteignez la moitié du set Horreur, 0 carte sur 40, plus que 20.",
        card_back_label(row("set-theme-horror", state: :locked, progress: progress(0, 40, 20)))
      assert_equal "20 / 40 cartes", card_back_tail(row("set-theme-horror", state: :locked, progress: progress(20, 40, 20)))
      assert_equal [ "Set absent de la saison en cours", nil ], strip(row("set-theme-horror", state: :locked))
    end
    I18n.with_locale(:en) do
      assert_equal [ "Reach half of the Horror set", "12 / 40 cards · 8 to go" ], strip(horror)
      assert_equal "Horror, locked. Reach half of the Horror set, 12 of 40 cards, 8 to go.", card_back_label(horror)
      assert_equal "Set not in the current season", card_back_sentence(row("set-theme-horror", state: :locked))
    end
  end

  test "equipping is announced with the season mark the back wears" do
    back = Game::CardBacks.find("set-theme-roguelike")

    I18n.with_locale(:fr) do
      assert_equal "Dos équipé. « Centurion » apparaîtra sur vos cartes face cachée.", card_back_equipped(Game::CardBacks.find("centurion"), nil)
      assert_equal "Dos équipé. « Roguelike », marque de la saison 1, apparaîtra sur vos cartes face cachée.", card_back_equipped(back, 1)
      assert_equal "Équiper Roguelike avec la marque de la saison 1", card_back_season_label(back, 1)
    end
    I18n.with_locale(:en) do
      assert_equal "Card back equipped. Roguelike, with the mark of season 2, will show on your face-down cards.", card_back_equipped(back, 2)
    end
  end
end
