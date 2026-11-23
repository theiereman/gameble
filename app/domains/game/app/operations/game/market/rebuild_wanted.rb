module Game
  module Market
    class RebuildWanted < Operation
      def call(player:)
        player = step require_account(player)

        transaction do
          step lock_bank(player)
          RefreshWanted.call(player)
          player
        end
      end
    end
  end
end
