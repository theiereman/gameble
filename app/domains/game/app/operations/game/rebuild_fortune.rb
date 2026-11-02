module Game
  class RebuildFortune < Operation
    def call(player:)
      player = step require_account(player)

      transaction do
        step lock_bank(player)
        Fortune.rebuild(player.id, Time.current)
        player
      end
    end
  end
end
