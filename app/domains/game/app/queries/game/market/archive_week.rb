module Game
  module Market
    # How the week's list of the Archives sells, for the back-office: editions listed and sold out, copies sold, the coefficient and prices.
    module ArchiveWeek
      Summary = Data.define(:listed, :sold_out, :copies_sold, :coefficient, :prices)

      def self.call(settings, now: Time.current)
        listed = ArchiveOffers.list(settings, now:)
        Summary.new(listed: listed.size, sold_out: listed.size - ArchiveStock.where(card_season_id: listed).count,
          copies_sold: ArchiveWithdrawal.where(created_at: ArchivePrices.week_start(now)..).count,
          coefficient: ArchivePrices.week_coefficient(now).to_f.round(2), prices: ArchivePrices.call(settings, now:).slice(*ArchiveOffers::LISTED))
      end
    end
  end
end
