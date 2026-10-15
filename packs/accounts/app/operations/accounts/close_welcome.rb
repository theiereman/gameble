module Accounts
  # Closes a new player's welcome panel for good, on every device: the hub
  # once it has shown the panel, or the panel's close button. A player whose
  # welcome is already closed, banned or deleted is left as they are.
  # Housekeeping: it publishes no event.
  #
  #   Accounts::CloseWelcome.new.call(player_id: player.id)
  #   # => Success(true) when it closed the welcome, Success(false) otherwise
  class CloseWelcome < ApplicationOperation
    def call(player_id:)
      transaction do
        Player.in_good_standing.where(id: player_id, welcome_pending: true).update_all(welcome_pending: false).positive?
      end
    end
  end
end
