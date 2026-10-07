module Game
  # Cuts off the players already removed when it runs (R6, AD-14): every
  # deleted or banned player still named by a friendship, an invitation or
  # an open trade gets one Game::DropFriendsAndTrades, each in its own
  # transaction. That covers the accounts deleted before the deletion did
  # it itself, and the bans set from the console until moderation publishes
  # Accounts::PlayerBanned (story 7.5). A player whose run fails is reported
  # and skipped, so the others are still released; a rerun finds nothing
  # more to do.
  #
  # Run once after the deploy, and after a console ban:
  # `bin/rails game:drop_friends_and_trades`.
  class DropFriendsAndTradesJob < ActiveJob::Base
    queue_as :default

    # The deleted or banned players still tied to another.
    def self.players_with_ties
      removed = Accounts::Player.where.not(deleted_at: nil).or(Accounts::Player.where.not(banned_at: nil))
      tied = [
        Friendship.select(:low_player_id), Friendship.select(:high_player_id),
        Invitation.select(:sender_id), Invitation.select(:recipient_id),
        Trade.in_progress.select(:proposer_id), Trade.in_progress.select(:recipient_id)
      ].map { |ids| Accounts::Player.where(id: ids) }.reduce(:or)
      removed.and(tied)
    end

    def perform
      self.class.players_with_ties.find_each do |player|
        DropFriendsAndTrades.new.call(player:).value!
      rescue StandardError => error
        Rails.error.report(error, context: { player_id: player.id })
      end
    end
  end
end
