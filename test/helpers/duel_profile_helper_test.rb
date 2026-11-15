require "test_helper"

class DuelProfileHelperTest < ActionView::TestCase
  def stat(name, percentile, value = 1)
    Game::DuelProfiles::Stat.new(name:, value:, percentile: BigDecimal(percentile.to_s), median_distance: 0.0, weekly_percentile: nil)
  end

  test "the words name the stronger side with a whole percent" do
    I18n.with_locale(:en) do
      assert_equal "More obscure than 88% of cards", duel_stat_words(stat(:popularity, 12), rarity: "epic")
      assert_equal "More popular than 50% of cards", duel_stat_words(stat(:popularity, 50), rarity: "epic")
      assert_equal "Discovered after 51% of cards", duel_stat_words(stat(:discovery, 49.5), rarity: "epic")
      assert_equal "Harder to find than 90% of Uncommon cards", duel_stat_words(stat(:circulation, 10), rarity: "uncommon")
      assert_equal "More popular than 99% of cards", duel_stat_words(stat(:popularity, 99.7), rarity: "epic")
      assert_equal "More obscure than 99% of cards", duel_stat_words(stat(:popularity, 0.2), rarity: "epic")
    end
    I18n.with_locale(:fr) do
      assert_equal "Plus confidentielle que 88 % des cartes", duel_stat_words(stat(:popularity, 12), rarity: "epic")
      assert_equal "Plus répandue que 97 % des cartes peu communes", duel_stat_words(stat(:circulation, 96.5), rarity: "uncommon")
    end
  end

  test "the raw values in words" do
    I18n.with_locale(:en) do
      assert_equal "12,345 reviews", duel_stat_value(stat(:popularity, 50, 12_345))
      assert_equal "91% positive", duel_stat_value(stat(:rating, 50, 91))
      assert_equal "October 10, 2007", duel_stat_value(stat(:release, 50, Date.new(2007, 10, 10)))
      assert_equal "1 player", duel_stat_value(stat(:circulation, 50, 1))
    end
    I18n.with_locale(:fr) do
      assert_equal "1er mars 2026", duel_stat_value(stat(:discovery, 50, Time.zone.local(2026, 3, 1, 12)))
      assert_equal "3 joueurs", duel_stat_value(stat(:circulation, 50, 3))
      assert_equal "91 % positives", duel_stat_value(stat(:rating, 50, 91))
    end
  end

  test "the bar's value and the date line" do
    assert_equal "12.5", duel_stat_bar_value(stat(:rating, 12.5))
    profile = Game::DuelProfiles::Profile.new(card_season_id: 1, stats: [], trump_stat: :rating, trump_direction: "high",
      computed_at: Time.utc(2026, 11, 16))
    I18n.with_locale(:fr) { assert_equal "Valeurs du 16 novembre 2026", duel_profile_dated(profile) }
  end
end
