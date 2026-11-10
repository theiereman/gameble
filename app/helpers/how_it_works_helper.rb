module HowItWorksHelper
  OddsRow = Data.define(:tier, :key, :percent)
  MarketRow = Data.define(:tier, :key, :entrustment, :stamp, :minimum_price)
  WHOLE_DAYS_FROM_HOURS = 48

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

  def basis_points_percent(basis_points)
    share_percent(basis_points, 10_000)
  end

  def market_duration(hours)
    return t("pages.how_it_works.market.days", count: hours / 24) if hours >= WHOLE_DAYS_FROM_HOURS && (hours % 24).zero?

    t("pages.how_it_works.market.hours", count: hours)
  end

  def market_rarity_rows(rules)
    Catalog::Rarity::TIERS.sort.map do |tier, key|
      MarketRow.new(tier:, key:, entrustment: picoins(rules.entrustment.fetch(key)), stamp: picoins(rules.stamp.fetch(key)),
                    minimum_price: picoins(rules.minimum_price.fetch(key)))
    end
  end

  def soft_close_minutes(rules)
    t("pages.how_it_works.minutes", count: rules.soft_close_seconds / 60)
  end

  private
    def share_percent(part, whole)
      number_to_percentage(BigDecimal(part) * 100 / whole, precision: 2, strip_insignificant_zeros: true)
    end
end
