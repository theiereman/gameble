module Game
  class ReceiveSeasonAllocation < Operation
    def call(player:, season: Catalog::PublishedSeason.call)
      player = step require_account(player)
      return Success([]) if season.nil?

      transaction do
        BankLock.acquire(player.id)
        state = locked_state(player)
        next [] if state.allocation_received_season.to_i >= season.number

        carried = SetTier.receive(player_id: player.id, season_id: season.id, now: Time.current)
        state.update!(allocation_received_season: season.number)
        step publish(SeasonAllocationReceived.new(data: { player_id: player.id, season_number: season.number, tiers: carried }),
          stream_name: stream_name(player.id))
        carried
      end
    end

    private

    def locked_state(player)
      PlayerState.insert({ player_id: player.id }, unique_by: :player_id)
      PlayerState.lock.find_by!(player_id: player.id)
    end
  end
end
