module Accounts
  # A moderator or an administrator lifts a player's ban: the player can sign
  # in again and their profile shows again. Friendships and trades dropped by
  # the ban stay dropped, and the reports the ban handled stay handled.
  #
  #   Accounts::UnbanPlayer.new.call(staff:, player:)
  #   # => Success(player) | Failure(:staff_required | :player_not_found | :not_banned)
  class UnbanPlayer < ApplicationOperation
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
      return Failure(:staff_required) unless Player.acting_staff?(staff)
      return Failure(:player_not_found) unless player.is_a?(Player) && player.persisted? && !player.deleted?

      player.banned? ? Success() : Failure(:not_banned)
    end
  end
end
