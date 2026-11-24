module Game
  module Market
    # The open orders another player's copy of an edition can serve: on its card, reaching its rarity at the order's own version,
    # placed by someone other than the seller and still playing; best price first, then the oldest.
    module EligibleOrders
      PRIORITY = { price: :desc, created_at: :asc, id: :asc }.freeze

      def self.call(card_season_id, except:, now: Time.current)
        card_id, rarity = Catalog::CardSeason.where(id: card_season_id).pick(:card_id, :rarity)
        return Order.none if rarity.nil?

        eligible([ card_id ], rarity, except:, now:).order(PRIORITY)
      end

      # The best eligible order of each edition, by card-season id; an edition no order reaches is left out.
      def self.best(card_season_ids, except:, now: Time.current)
        by_edition(card_season_ids) do |rarity, card_ids|
          eligible(card_ids, rarity, except:, now:).select("DISTINCT ON (game_market_orders.card_id) game_market_orders.*").order(:card_id, PRIORITY).index_by(&:card_id)
        end
      end

      # Every eligible price of each edition, best first, by card-season id; an edition no order reaches is left out.
      def self.prices(card_season_ids, except:, now: Time.current)
        by_edition(card_season_ids) do |rarity, card_ids|
          eligible(card_ids, rarity, except:, now:).order(:card_id, PRIORITY).pluck(:card_id, :price).group_by(&:first).transform_values { |rows| rows.map(&:last) }
        end
      end

      def self.draw(edition_counts, except:, now: Time.current)
        editions = Catalog::CardSeason.where(id: edition_counts.map(&:first)).where.not(rarity: nil).pluck(:id, :card_id, :rarity).index_by(&:first)
        taken = []
        edition_counts.map do |card_season_id, count|
          _id, card_id, rarity = editions[card_season_id]
          next [] if rarity.nil? || count.zero?

          orders = eligible([ card_id ], rarity, except:, now:).where.not(id: taken).order(PRIORITY).limit(count).to_a
          taken.concat(orders.map(&:id))
          orders
        end
      end

      def self.eligible(card_ids, rarity, except:, now:)
        Order.open_at(now).where(card_id: card_ids).reaching(rarity).where.not(player_id: except)
          .where.not(player_id: Accounts::Player.removed.select(:id))
      end
      private_class_method :eligible

      # What the block finds of the cards of one rarity, handed to each edition of those cards.
      def self.by_edition(card_season_ids)
        editions = Catalog::CardSeason.where(id: card_season_ids).where.not(rarity: nil).pluck(:id, :card_id, :rarity)
        editions.group_by(&:third).each_with_object({}) do |(rarity, rows), found|
          per_card = yield rarity, rows.map(&:second)
          rows.each { |id, card_id, _| found[id] = per_card[card_id] if per_card.key?(card_id) }
        end
      end
      private_class_method :by_edition
    end
  end
end
