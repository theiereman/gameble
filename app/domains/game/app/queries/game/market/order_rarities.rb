module Game
  module Market
    # The rarities each order reaches, in rarity order: those its card is published at whose minimum its price meets (Order.reaching).
    module OrderRarities
      def self.call(order_ids)
        ids = Array(order_ids)
        reached = ids.index_with { [] }
        return reached if ids.empty?

        cards = Order.where(id: ids).pluck(:id, :card_id).to_h
        published = Catalog::PublishedCardRarities.call(cards.values)
        SettingsRules::RARITIES.each do |rarity|
          Order.where(id: ids).reaching(rarity).pluck(:id).each { reached[it] << rarity if published[cards[it]]&.include?(rarity) }
        end
        reached
      end
    end
  end
end
