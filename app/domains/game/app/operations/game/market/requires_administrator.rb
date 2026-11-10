module Game
  module Market
    # Halts the operation unless the acting player is an administrator, before any write.
    module RequiresAdministrator
      private

      def require_administrator(player)
        Accounts::Player.acting_staff?(player) && player.administrator? ? Success(player) : Failure(:administrator_required)
      end
    end
  end
end
