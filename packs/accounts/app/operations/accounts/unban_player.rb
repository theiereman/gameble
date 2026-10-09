module Accounts
  # A moderator or an administrator lifts the ban of a player they outrank:
  # the player can sign in again and their profile shows again. Friendships
  # and trades dropped by the ban stay dropped, and the reports the ban
  # handled stay handled. The refusal is read again from the locked row, as
  # Accounts::BanPlayer does; the list of banned players asks it too.
  #
  #   Accounts::UnbanPlayer.new.call(staff:, player:)
  #   # => Success(player) | Failure(:staff_required | :player_not_found |
  #   #    :outranked | :not_banned)
  class UnbanPlayer < ApplicationOperation
    def self.refusal(staff:, player:)
      return :staff_required unless Player.acting_staff?(staff)
      return :player_not_found unless player.is_a?(Player) && player.persisted? && !player.deleted?
      return :outranked unless staff.outranks?(player)

      :not_banned unless player.banned?
    end

    def call(staff:, player:)
      step permitted(staff, player)

      transaction do
        player.lock!("FOR NO KEY UPDATE")
        step permitted(staff, player)
        step publish(PlayerUnbanned.new(data: { player_id: player.id, staff_id: staff.id }), stream_name: "Accounts::Player$#{player.id}")
        player.update!(banned_at: nil)
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
