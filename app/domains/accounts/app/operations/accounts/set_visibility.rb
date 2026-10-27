module Accounts
  class SetVisibility < ApplicationOperation
    def call(player:, visibility:)
      player = step require_player(player)
      visibility = step check(visibility)

      transaction do
        player.lock!("FOR NO KEY UPDATE")
        step require_player(player)
        next player if player.visibility == visibility

        step publish(VisibilityChanged.new(data: { player_id: player.id, visibility: }), stream_name: "Accounts::Player$#{player.id}")
        player.update!(visibility:)
        player
      end
    end

    private

    def require_player(player)
      player.is_a?(Player) && player.persisted? && !player.banned? ? Success(player) : Failure(:player_required)
    end

    def check(visibility)
      return Failure(:invalid_setting) unless visibility.is_a?(String) || visibility.is_a?(Symbol)

      Player.visibilities.key?(visibility.to_s) ? Success(visibility.to_s) : Failure(:invalid_setting)
    end
  end
end
