module Game
  class UnlockCardBack < Operation
    def call(player:, back:, retroactive: false)
      player = step require_player(player)
      back = step known(back)

      transaction do
        step unlock(player, back)
        step publish(CardBackUnlocked.new(data: event_data(player, back, retroactive)), stream_name: stream_name(player.id))
        back
      end
    end

    private

    def known(key)
      back = CardBacks.find(key)
      return Failure(:unknown_back) unless back

      back.key == CardBacks::STANDARD ? Failure(:already_unlocked) : Success(back)
    end

    def unlock(player, back)
      CardBackUnlock.record(player.id, back.key, Time.current) ? Success() : Failure(:already_unlocked)
    end

    def event_data(player, back, retroactive)
      data = { player_id: player.id, back: back.key }
      retroactive ? data.merge(retroactive: true) : data
    end
  end
end
