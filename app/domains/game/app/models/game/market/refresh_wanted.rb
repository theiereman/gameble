module Game
  module Market
    # The only writer of the wanted table: replaces a player's rows from their goals' missing games and their open orders.
    module RefreshWanted
      def self.call(player, now: Time.current)
        raise ArgumentError, "the bank lock of player #{player.id} is not held" unless BankLock.held?(player.id)

        Wanted.where(player_id: player.id).delete_all
        return if player.removed?

        rows = goal_rows(player) + order_rows(player, now)
        Wanted.insert_all(rows) if rows.any?
      end

      def self.goal_rows(player)
        GoalNeeds.call(player).flat_map(&:missing_card_ids).uniq.map { |card_id| { player_id: player.id, card_id:, reason: "goal", rarities: nil } }
      end

      def self.order_rows(player, now)
        orders = Order.where(player_id: player.id).open_at(now).pluck(:id, :card_id)
        reached = OrderRarities.call(orders.map(&:first))
        orders.filter_map do |id, card_id|
          tiers = reached.fetch(id).map { Catalog::Rarity::TIERS.key(it) }
          { player_id: player.id, card_id:, reason: "order", rarities: tiers } if tiers.any?
        end
      end

      private_class_method :goal_rows, :order_rows
    end
  end
end
