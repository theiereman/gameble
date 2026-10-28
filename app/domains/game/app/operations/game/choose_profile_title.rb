module Game
  class ChooseProfileTitle < Operation
    def call(player:, rank: nil, kind: nil, key: nil)
      player = step require_player(player)
      title = step earned(player, rank:, kind:, key:)

      transaction do
        step lock_bank(player)
        store(player, title)
        step publish(ProfileTitleChosen.new(data: { player_id: player.id, kind: title&.kind, key: title&.key, rank: title&.rank }),
          stream_name: stream_name(player.id))
        title
      end
    end

    private

    def earned(player, rank:, kind:, key:)
      return Success(nil) if [ rank, kind, key ].all?(&:nil?)

      title = ProfileTitles.call(player).find { it.rank == rank && it.kind == kind && it.key == key }
      title ? Success(title) : Failure(:title_not_earned)
    end

    def store(player, title)
      PlayerState.insert({ player_id: player.id }, unique_by: :player_id)
      PlayerState.where(player_id: player.id).update_all(
        active_title_kind: title&.kind, active_title_key: title&.key, active_title_rank: title&.rank, updated_at: Time.current
      )
    end
  end
end
