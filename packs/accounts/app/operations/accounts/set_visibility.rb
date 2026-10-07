module Accounts
  # Sets who may see a player's profile (CAP-14, AD-14): "public",
  # "friends_only" or "private". Housekeeping: it publishes no event (AD-10).
  #
  #   Accounts::SetVisibility.new.call(player:, visibility: "private")
  #   # => Success(player) | Failure(:player_required) | Failure(:invalid_setting)
  class SetVisibility < ApplicationOperation
    def call(player:, visibility:)
      player = step require_player(player)
      visibility = step check(visibility)

      transaction do
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
