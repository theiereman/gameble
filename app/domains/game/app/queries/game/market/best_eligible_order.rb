module Game
  module Market
    # The order a sale of a copy of this edition serves, if any.
    module BestEligibleOrder
      def self.call(card_season_id, except:, now: Time.current) = EligibleOrders.call(card_season_id, except:, now:).first
    end
  end
end
