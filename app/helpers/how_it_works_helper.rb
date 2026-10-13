# The numbers of the how-it-works screen, each read from the constant the
# game applies, so the screen never states a rule the game no longer
# follows. Percentages go through the locale's number format.
#
#   odds_percent(430)                    # => "4.3%" ("4,3 %" in French)
#   odds_rows(Game::DrawOdds::BONUS)     # => [#<data OddsRow tier: 2, key: :uncommon, percent: "70%">, …]
#   rarity_shares                        # => { legendary: "1%", epic: "4%", …, common: "60%" }
module HowItWorksHelper
  OddsRow = Data.define(:tier, :key, :percent)

  def odds_percent(parts)
    share_percent(parts, Game::DrawOdds::TOTAL)
  end

  def odds_rows(odds)
    odds.sort.map { |tier, parts| OddsRow.new(tier:, key: Catalog::Rarity::TIERS.fetch(tier), percent: odds_percent(parts)) }
  end

  def rarity_shares
    shares = Catalog::RarityThresholds::SHARES
    rest = Catalog::RarityThresholds::BASIS - shares.values.sum
    Catalog::Rarity::TIERS.keys.sort.reverse.to_h do |tier|
      [ Catalog::Rarity::TIERS.fetch(tier), share_percent(shares.fetch(tier, rest), Catalog::RarityThresholds::BASIS) ]
    end
  end

  def pack_interval_minutes
    Game::Pack::INTERVAL.in_minutes.to_i
  end

  def bank_refill_minutes
    (Game::Pack::BANK_SIZE * Game::Pack::INTERVAL).in_minutes.to_i
  end

  def set_tier_percents
    Catalog::Themes::TIER_PERCENTS.transform_values { |percent| number_to_percentage(percent, precision: 0) }
  end

  private
    def share_percent(part, whole)
      number_to_percentage(BigDecimal(part) * 100 / whole, precision: 2, strip_insignificant_zeros: true)
    end
end
