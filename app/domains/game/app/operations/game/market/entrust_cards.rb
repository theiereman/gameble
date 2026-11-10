module Game
  module Market
    # A player gives free copies to the Archives and receives the PiCoins minted for them, at the values of the settings version the form drew.
    class EntrustCards < Operation
      include MoveHoldings

      Entrusted = Data.define(:minted, :copies)

      # lines: card-season id => copies; settings_token: the version the form drew its amounts from.
      def call(player:, lines:, settings_token:)
        player = step require_player(player)
        lines = step normalise(lines)

        transaction do
          step lock_bank(player)
          settings = step current_settings(settings_token)
          holdings = TradeLocks.holdings(player.id, lines.keys)
          step enough_copies(lines, holdings)
          minted = step minted_for(lines, settings)
          deposit(player, lines, holdings)
          Mint.credit(player_id: player.id, amount: minted, settings_id: settings.id)
          step publish(CardsEntrusted.new(data: { player_id: player.id, cards: lines.map { |card_season_id, copies| { card_season_id:, copies: } } }),
            stream_name: stream_name(player.id))
          Entrusted.new(minted:, copies: lines.values.sum)
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
        counts.empty? ? Failure(:empty_batch) : Success(counts.sort.to_h)
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

      def minted_for(lines, settings)
        rarities = Catalog::CardSeason.where(id: lines.keys).pluck(:id, :rarity).to_h
        return Failure(:no_rarity) if lines.keys.any? { rarities[it].nil? }

        Success(lines.sum { |card_season_id, copies| settings.entrustment(rarities.fetch(card_season_id)) * copies })
      end

      def deposit(player, lines, holdings)
        now = Time.current
        move(player.id, holdings, given: lines, gained: {}, released: {}, now:)
        ShowcaseEntry.remove_unheld(player.id, lines.keys)
        ArchiveDeposit.add(player.id, lines, now)
      end
    end
  end
end
