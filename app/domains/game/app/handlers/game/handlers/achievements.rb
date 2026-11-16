module Game
  module Handlers
    module Achievements
      EVENTS = {
        Game::PackOpened => [ :player_id ],
        Game::SetCompleted => [ :player_id ],
        Game::SeasonAllocationReceived => [ :player_id ],
        Game::CardDiscovered => [ :player_id ],
        Game::CardReposted => [ :player_id ],
        Game::DailyBonusCollected => [ :player_id ],
        Game::PackRevealed => [ :player_id ],
        Game::TradeAccepted => [ :proposer_id, :recipient_id ],
        Game::Market::AuctionSold => [ :seller_id, :winner_id ],
        Game::Market::CardsEntrusted => [ :player_id ],
        Game::FeedEntryReacted => [ :player_id, :author_id, :partner_id ],
        Game::InvitationAccepted => [ :sender_id, :recipient_id ],
        Game::ShowcaseCardAdded => [ :player_id ],
        Game::ShowcaseCardRemoved => [ :player_id ],
        Game::CustomSetCreated => [ :player_id ],
        Game::CustomSetEdited => [ :player_id ]
      }.freeze

      def self.call(event)
        return if removed_reaction?(event)

        EVENTS.fetch(event.class).map { event.data.fetch(it) }.compact.uniq.each { GrantAchievementsJob.perform_later(it) }
      end

      def self.removed_reaction?(event) = event.is_a?(Game::FeedEntryReacted) && event.data.fetch(:kind).nil?
      private_class_method :removed_reaction?
    end
  end
end
