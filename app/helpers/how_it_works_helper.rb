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

  private
    def share_percent(part, whole)
      number_to_percentage(BigDecimal(part) * 100 / whole, precision: 2, strip_insignificant_zeros: true)
    end
end
