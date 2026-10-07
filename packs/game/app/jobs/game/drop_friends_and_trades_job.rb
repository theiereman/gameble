module Game
  class DropFriendsAndTradesJob < ActiveJob::Base
    queue_as :default

    def self.players_with_ties
      tied = [
        Friendship.select(:low_player_id), Friendship.select(:high_player_id),
        Invitation.select(:sender_id), Invitation.select(:recipient_id),
        Trade.in_progress.select(:proposer_id), Trade.in_progress.select(:recipient_id)
      ].map { |ids| Accounts::Player.where(id: ids) }.reduce(:or)
      Accounts::Player.removed.and(tied)
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
