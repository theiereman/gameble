module Game
  module TradeSuggestions
    module Spares
      Spare = Data.define(:card_id, :edition, :goal_positions, :copies) do
        def rank = [ goal_positions.min, -edition.rarity, edition.slug ]
      end

      def self.from_friends(player, friend_ids, wanted, declined, now)
        taken = OpenTrades.requested_by(player, friend_ids, now) | declined.request
        spares = Hash.new { |hash, friend_id| hash[friend_id] = [] }
        FreeEditions.call(friend_ids, wanted.keys).each do |(friend_id, card_id), editions|
          next if taken.include?([ friend_id, card_id ])

          next unless FreeEditions.copies(editions) >= TradeSuggestions::DUPLICATE_COPIES

          edition = FreeEditions.placed(editions) or next
          spares[friend_id] << Spare.new(card_id:, edition:, copies: FreeEditions.copies(editions), goal_positions: wanted.fetch(card_id).uniq.sort)
        end
        spares.to_h { |friend_id, list| [ friend_id, list.sort_by(&:rank) ] }
      end

      def self.from_player(player, friend_ids, declined, now)
        return {} if friend_ids.empty?

        gaps = GameSetGaps.call(friend_ids)
        return {} if gaps.empty?

        spared = FreeEditions.call([ player.id ], nil).filter_map do |(_, card_id), editions|
          next unless FreeEditions.copies(editions) >= TradeSuggestions::DUPLICATE_COPIES

          (edition = FreeEditions.placed(editions)) && [ card_id, edition, FreeEditions.copies(editions) ]
        end
        return {} if spared.empty?

        offered = OpenTrades.offered_by(player, friend_ids, now) | declined.offer
        friend_ids.each_with_object({}) do |friend_id, gives|
          missed = gaps.fetch(friend_id, {})
          list = spared.filter_map do |card_id, edition, copies|
            next unless missed.key?(card_id) && !offered.include?([ friend_id, card_id ])

            Spare.new(card_id:, edition:, copies:, goal_positions: missed.fetch(card_id).uniq.sort)
          end
          gives[friend_id] = list.sort_by(&:rank).map { it.with(goal_positions: []) } if list.any?
        end
      end
    end
  end
end
