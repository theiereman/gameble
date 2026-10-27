module Accounts
  # Gives a player, found by their Steam id, the role of player, moderator or
  # administrator. Run from `bin/rails "accounts:set_role[<steam id>,<role>]"`:
  # no page assigns roles. Setting the role a player already holds changes
  # nothing and publishes nothing.
  #
  #   Accounts::SetRole.new.call(steam_id: "76561197960287002", role: "moderator")
  #   # => Success(player) | Failure(:player_not_found | :invalid_role)
  class SetRole < ApplicationOperation
    def call(steam_id:, role:)
      role = step check(role)
      player = step find(steam_id)

      transaction do
        player.lock!("FOR NO KEY UPDATE")
        next player if player.role == role

        step publish(RoleChanged.new(data: { player_id: player.id, role: }), stream_name: "Accounts::Player$#{player.id}")
        player.update!(role:)
        player
      end
    end

    private

    def check(role)
      return Failure(:invalid_role) unless role.is_a?(String) || role.is_a?(Symbol)

      Player.roles.key?(role.to_s) ? Success(role.to_s) : Failure(:invalid_role)
    end

    def find(steam_id)
      player = Player.find_by(steam_id: steam_id.to_s.strip, deleted_at: nil) if steam_id.is_a?(String) || steam_id.is_a?(Integer)
      player ? Success(player) : Failure(:player_not_found)
    end
  end
end
