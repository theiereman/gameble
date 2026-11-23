module Game
  module Handlers
    module Metrics
      COUNTERS = {
        Accounts::PlayerRegistered => "player.registered",
        Game::PackOpened => "pack.opened",
        Game::SlotBought => "slot.bought",
        Game::DuelChallengeAccepted => "duel.started",
        Game::DuelFinished => "duel.finished",
        Game::Market::OrderPlaced => "market.order.placed",
        Game::Market::OrderServed => "market.order.served",
        Game::Market::OrderExpired => "market.order.expired",
        Game::Market::OrderCancelled => "market.order.cancelled",
        Game::Market::OrderWithdrawn => "market.order.withdrawn",
        Game::Market::ArchivePurchased => "market.archive.purchased",
        Game::Market::AuctionSold => "market.auction.sold",
        Game::Market::AuctionUnsold => "market.auction.unsold",
        Game::Market::WantedChoicesApplied => "market.wanted_choices.applied"
      }.freeze
      AMOUNTS = {
        Game::Market::OrderServed => [ "market.order.served.price", :price ],
        Game::Market::ArchivePurchased => [ "market.archive.purchased.price", :price ]
      }.freeze
      EVENTS = COUNTERS.keys.freeze

      def self.call(event)
        ActiveRecord.after_all_transactions_commit { emit(event) }
      end

      def self.emit(event)
        Sentry::Metrics.count(COUNTERS.fetch(event.class), attributes: attributes(event))
        name, field = AMOUNTS[event.class]
        Sentry::Metrics.distribution(name, event.data.fetch(field), unit: "picoin") if name
      rescue StandardError => error
        Rails.error.report(error, handled: true)
      end

      def self.attributes(event) = event.is_a?(Game::SlotBought) ? { kind: event.data.fetch(:kind).to_s } : nil
      private_class_method :emit, :attributes
    end
  end
end
