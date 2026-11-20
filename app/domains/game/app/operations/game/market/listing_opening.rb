module Game
  module Market
    # Opens one auction on a free copy and reserves it, under the locks the caller holds; returns the listing and its stamp entry to post.
    module ListingOpening
      include PriceAmount

      private

      def price_rule(settings, rarity, starting_price)
        starting_price < settings.minimum_price(rarity) ? Failure(:start_below_minimum) : Success()
      end

      def duration_rule(settings, duration_hours)
        allowed = [ settings.duration_short_hours, settings.duration_medium_hours, settings.duration_long_hours ]
        allowed.include?(whole_number(duration_hours)) ? Success() : Failure(:invalid_duration)
      end

      def open_listing(player, holding, settings, rarity, starting_price, duration_hours)
        hours = whole_number(duration_hours)
        listing = Listing.create!(seller: player, card_season_id: holding.card_season_id, settings_id: settings.id, starting_price:, duration_hours: hours,
          ends_at: hours.hours.from_now, current_price: starting_price)
        Holding.where(id: holding.id).update_all([ "reserved = reserved + 1, updated_at = ?", Time.current ])
        [ listing, Ledger::Entry.new(player_id: player.id, kind: :stamp, available_delta: -settings.stamp(rarity), listing_id: listing.id, settings_id: settings.id) ]
      end
    end
  end
end
