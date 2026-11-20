module Game
  module Market
    # The rarities each order reaches, in rarity order, judged only by Order.reaching.
    module OrderRarities
      def self.call(order_ids)
        ids = Array(order_ids)
        reached = ids.index_with { [] }
        return reached if ids.empty?

        SettingsRules::RARITIES.each do |rarity|
          Order.where(id: ids).reaching(rarity).pluck(:id).each { reached[it] << rarity }
        end
        reached
      end
    end
  end
end
