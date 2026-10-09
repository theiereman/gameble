module Accounts
  # A moderator or an administrator bans a player they outrank. Game drops
  # the player's trades and friendships on Accounts::PlayerBanned; the
  # player's open reports are handled, so lifting the ban does not bring
  # them back.
  #
  # The row is locked FOR NO KEY UPDATE before publishing, as
  # Accounts::DeletePlayer does, and the refusal is read again from the
  # locked row, so a promotion committed meanwhile counts. `banned_at` is
  # written last: that write rotates the unique stream key, so it takes FOR
  # UPDATE.
  #
  #   Accounts::BanPlayer.new.call(staff:, player:)
  #   # => Success(player) | Failure(:staff_required | :player_not_found |
  #   #    :cannot_ban_self | :outranked | :already_banned)
  class BanPlayer < ApplicationOperation
    def self.refusal(staff:, player:)
      return :staff_required unless Player.acting_staff?(staff)
      return :player_not_found unless player.is_a?(Player) && player.persisted? && !player.deleted?
      return :cannot_ban_self if player.id == staff.id
      return :outranked unless staff.outranks?(player)

      :already_banned if player.banned?
    end

    def call(staff:, player:)
      step permitted(staff, player)

      transaction do
        player.lock!("FOR NO KEY UPDATE")
        step permitted(staff, player)
        step publish(PlayerBanned.new(data: { player_id: player.id, staff_id: staff.id }), stream_name: "Accounts::Player$#{player.id}")
        now = Time.current
        Report.unhandled.where(reported: player).update_all(handled_at: now, updated_at: now)
        player.update!(banned_at: now)
        player
      end
    end

    private

    def permitted(staff, player)
      code = self.class.refusal(staff:, player:)
      code ? Failure(code) : Success()
    end
  end
end
