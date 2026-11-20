module Game
  module Market
    # A player gives free copies to the Archives and receives the PiCoins minted for them, at the values of the settings version the form drew.
    class EntrustCards < Operation
      include Entrusting

      Stayed = Data.define(:card_season_id, :copies, :value)
      Entrusted = Data.define(:minted, :copies, :stayed, :cap_left)

      # lines: card-season id => copies; settings_token: the version the form drew its amounts from.
      def call(player:, lines:, settings_token:)
        player = step require_player(player)
        lines = step normalise(lines)

        transaction do
          step lock_bank(player)
          settings = step current_settings(settings_token)
          holdings = TradeLocks.holdings(player.id, lines.keys)
          step enough_copies(lines, holdings)
          values = step values_of(lines.keys, settings)
          cap_left = CapLeft.call(player.id, settings:)
          entrusted, stayed = split_by_cap(lines, values, cap_left)
          step(Failure(:nothing_fits)) if entrusted.empty?
          mint = entrust(player.id, entrusted, holdings, values, settings, now: Time.current)
          Ledger.post(mint)
          step publish(CardsEntrusted.new(data: { player_id: player.id, cards: entrusted.map { |card_season_id, copies| { card_season_id:, copies: } } }),
            stream_name: stream_name(player.id))
          Entrusted.new(minted: mint.available_delta, copies: entrusted.values.sum, stayed: stayed_list(stayed, values), cap_left:)
        end
      rescue ActiveRecord::Deadlocked
        step Failure(:market_busy)
      end

      private

      def normalise(lines)
        counts = Hash.new(0)
        lines.to_h.each do |card_season_id, copies|
          card_season_id = Integer(card_season_id, exception: false)
          copies = Integer(copies, exception: false)
          counts[card_season_id] += copies if card_season_id&.positive? && copies&.positive?
        end
        counts.empty? ? Failure(:empty_batch) : Success(counts)
      end

      def current_settings(settings_token)
        settings = CurrentSettings.call
        return Failure(:market_closed) unless settings&.open
        return Failure(:amounts_changed) unless settings.token == settings_token

        Success(settings)
      end

      def enough_copies(lines, holdings)
        free = lines.all? { |card_season_id, copies| (holding = holdings[card_season_id]) && copies <= holding.quantity - holding.reserved }
        free ? Success() : Failure(:not_enough_copies)
      end

      def split_by_cap(lines, values, cap_left)
        fits = lines.keys.zip(copies_within_cap(lines, values, cap_left)).to_h
        stayed = lines.to_h { |card_season_id, copies| [ card_season_id, copies - fits.fetch(card_season_id) ] }
        [ fits.select { |_, copies| copies.positive? }, stayed.select { |_, copies| copies.positive? } ]
      end

      def stayed_list(stayed, values)
        stayed.map { |card_season_id, copies| Stayed.new(card_season_id:, copies:, value: values.fetch(card_season_id)) }
      end
    end
  end
end
