module Game
  module Market
    # A player offers one free copy at auction, paying the rarity's stamp, at the values of the settings version the form drew.
    class ListCard < Operation
      MAX_AMOUNT = 9_223_372_036_854_775_807

      # settings_token: the version the form drew its amounts from; buy_now_price may be empty.
      def call(player:, card_season_id:, starting_price:, buy_now_price:, duration_hours:, settings_token:)
        player = step require_player(player)
        starting_price = step amount(starting_price)
        buy_now_price = step optional_amount(buy_now_price)

        transaction do
          step lock_bank(player)
          settings = step current_settings(settings_token)
          rarity = step rarity_of(card_season_id)
          holding = step free_copy(TradeLocks.holdings(player.id, [ card_season_id ])[card_season_id])
          step price_rules(settings, rarity, starting_price, buy_now_price)
          step duration_rule(settings, duration_hours)
          step stamp_covered(settings, rarity, player)
          listing = create_listing(player, card_season_id, settings, starting_price, buy_now_price, duration_hours)
          reserve(holding)
          Ledger.post(Ledger::Entry.new(player_id: player.id, kind: :stamp, available_delta: -settings.stamp(rarity), listing_id: listing.id, settings_id: settings.id))
          step publish(CardListed.new(data: { listing_id: listing.id, seller_id: player.id, card_season_id: }), stream_name: stream_name(player.id))
          listing
        end
      rescue ActiveRecord::Deadlocked
        step Failure(:market_busy)
      end

      private

      def amount(value)
        number = Integer(value.to_s.strip, exception: false)
        number&.between?(1, MAX_AMOUNT) ? Success(number) : Failure(:invalid_price)
      end

      def optional_amount(value) = value.nil? || value.to_s.strip.empty? ? Success(nil) : amount(value)

      def current_settings(settings_token)
        settings = CurrentSettings.call
        return Failure(:market_closed) unless settings&.open
        return Failure(:amounts_changed) unless settings.token == settings_token

        Success(settings)
      end

      def rarity_of(card_season_id)
        rarity = Catalog::CardSeason.where(id: card_season_id).pick(:rarity)
        rarity ? Success(rarity.to_sym) : Failure(:no_rarity)
      end

      def free_copy(holding) = holding && holding.quantity > holding.reserved ? Success(holding) : Failure(:copy_not_free)

      def price_rules(settings, rarity, starting_price, buy_now_price)
        minimum = settings.minimum_price(rarity)
        return Failure(:start_below_minimum) if starting_price < minimum
        return Success() unless buy_now_price
        return Failure(:buy_now_below_minimum) if buy_now_price < minimum
        return Failure(:buy_now_not_above_start) if buy_now_price <= starting_price

        Success()
      end

      def duration_rule(settings, duration_hours)
        allowed = [ settings.duration_short_hours, settings.duration_medium_hours, settings.duration_long_hours ]
        allowed.include?(Integer(duration_hours.to_s, exception: false)) ? Success() : Failure(:invalid_duration)
      end

      def stamp_covered(settings, rarity, player)
        Balance.call(player).available >= settings.stamp(rarity) ? Success() : Failure(:stamp_not_covered)
      end

      def create_listing(player, card_season_id, settings, starting_price, buy_now_price, duration_hours)
        hours = Integer(duration_hours.to_s)
        Listing.create!(seller: player, card_season_id:, settings_id: settings.id, starting_price:, buy_now_price:, duration_hours: hours,
          ends_at: hours.hours.from_now, current_price: starting_price)
      end

      def reserve(holding)
        Holding.where(id: holding.id).update_all([ "reserved = reserved + 1, updated_at = ?", Time.current ])
      end
    end
  end
end
