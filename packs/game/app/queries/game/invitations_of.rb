module Game
  # A player's pending invitations (AD-8), newest first: the ones received,
  # each with its sender, and the ones sent, each with the recipient's friend
  # code. Banned and deleted players are left out (AD-13; a deletion drops
  # its invitations, Game::DropFriendsAndTrades, and this covers one sent
  # while it ran). Empty for a visitor.
  #
  #   Game::InvitationsOf.call(player) # => Result(received: [Row, ...], sent: [Row, ...])
  module InvitationsOf
    Row = Data.define(:token, :player, :code)
    Result = Data.define(:received, :sent)

    def self.call(player)
      return Result.new(received: [], sent: []) unless player

      rows = Invitation.pending.where(sender_id: player.id).or(Invitation.pending.where(recipient_id: player.id)).order(id: :desc).to_a
      others = rows.flat_map { |row| [ row.sender_id, row.recipient_id ] }.uniq - [ player.id ]
      players = Accounts::Player.where(id: others, banned_at: nil, deleted_at: nil).index_by(&:id)
      codes = FriendCode.where(player_id: others).pluck(:player_id, :code).to_h

      received = rows.select { |row| row.recipient_id == player.id }.filter_map do |row|
        sender = players[row.sender_id]
        Row.new(token: row.token, player: sender, code: codes[row.sender_id]) if sender
      end
      sent = rows.select { |row| row.sender_id == player.id }.filter_map do |row|
        recipient = players[row.recipient_id]
        Row.new(token: row.token, player: recipient, code: codes[row.recipient_id]) if recipient
      end
      Result.new(received:, sent:)
    end
  end
end
