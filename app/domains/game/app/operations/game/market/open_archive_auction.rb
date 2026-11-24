module Game
  module Market
    # The Archives put one copy of an edition up for auction, at the least ArchivePrices allows; the copy leaves their stock until the
    # auction ends unsold. No stamp is paid and no order converts.
    class OpenArchiveAuction < ApplicationOperation
      DURATION_HOURS = 48

      def call(card_season_id:, now: Time.current)
        transaction do
          settings = step open_settings
          rarity = step rarity_of(card_season_id)
          stock = step locked_stock(card_season_id)
          price = ArchivePrices.reserve(settings, rarity, now:)
          listing = Listing.create!(seller: nil, card_season_id:, settings_id: settings.id, starting_price: price, current_price: price,
            duration_hours: DURATION_HOURS, ends_at: now + DURATION_HOURS.hours)
          stock.take_one(now)
          step publish(CardListed.with(listing_id: listing.id, seller_id: nil, card_season_id:), stream_name: Operation.stream_name(nil))
          listing
        end
      end

      private

      def open_settings
        settings = CurrentSettings.call
        settings&.open ? Success(settings) : Failure(:market_closed)
      end

      def rarity_of(card_season_id)
        rarity = Catalog::CardSeason.where(id: card_season_id).pick(:rarity)&.to_sym
        ArchiveAuctionPicks::RARITIES.key?(rarity) ? Success(rarity) : Failure(:not_in_shop)
      end

      def locked_stock(card_season_id)
        stock = ArchiveStock.lock.find_by(card_season_id:)
        stock ? Success(stock) : Failure(:out_of_stock)
      end
    end
  end
end
