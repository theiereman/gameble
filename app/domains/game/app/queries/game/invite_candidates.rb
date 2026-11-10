module Game
  module InviteCandidates
    MIN_QUERY = 2
    LIMIT = 8

    Row = Data.define(:player, :relation, :invitation_token)

    def self.call(player, query)
      text = Accounts::PersonaName.clean(query).to_s
      return [] if player.nil? || text.length < MIN_QUERY

      players = Accounts::PlayersNamed.call(text, excluding: player.id, limit: LIMIT)
      ids = players.map(&:id)
      friend_ids = Friendship.other_ids(player.id) & ids
      invited_ids = Invitation.unanswered.where(sender_id: player.id, recipient_id: ids).pluck(:recipient_id)
      received = Invitation.pending.where(sender_id: ids, recipient_id: player.id).pluck(:sender_id, :token).to_h

      players.map do |found|
        relation = if friend_ids.include?(found.id) then :friend
        elsif received.key?(found.id) then :invited_by
        elsif invited_ids.include?(found.id) then :invited
        else :none
        end
        Row.new(player: found, relation:, invitation_token: received[found.id])
      end
    end
  end
end
