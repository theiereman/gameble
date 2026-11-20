module Game
  module Market
    # Gives free copies to the Archives under the locks the caller holds; returns the mint entry to post.
    module Entrusting
      include MoveHoldings

      private

      def values_of(card_season_ids, settings)
        rarities = Catalog::CardSeason.where(id: card_season_ids).pluck(:id, :rarity).to_h
        return Failure(:no_rarity) if card_season_ids.any? { rarities[it].nil? }

        Success(card_season_ids.to_h { |card_season_id| [ card_season_id, settings.entrustment(rarities.fetch(card_season_id)) ] })
      end

      # Whole copies, line after line in the order given: a line that does not fit keeps its copies and a cheaper one after it may still pass.
      def copies_within_cap(lines, values, cap_left)
        lines.map do |card_season_id, copies|
          fits = [ copies, cap_left / values.fetch(card_season_id) ].min
          cap_left -= fits * values.fetch(card_season_id)
          fits
        end
      end

      # quantities: card-season id => copies, one entry per card-season.
      def entrust(player_id, quantities, holdings, values, settings, now:)
        move(player_id, holdings, given: quantities, gained: {}, released: {}, now:)
        ShowcaseEntry.remove_unheld(player_id, quantities.keys)
        ArchiveDeposit.add(player_id, quantities, now)
        Mint.credit(player_id:, amount: quantities.sum { |card_season_id, copies| values.fetch(card_season_id) * copies }, settings_id: settings.id)
      end
    end
  end
end
