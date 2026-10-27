module Game
  module ShowcaseSteps
    private

    def locked_entries(player)
      ShowcaseEntry.where(player_id: player.id).order(:position, :id).lock.to_a
    end

    def showcased(entries, card_season_id)
      index = entries.index { it.card_season_id == card_season_id }
      index ? Success(index) : Failure(:card_not_showcased)
    end

    def place(entries)
      now = Time.current
      entries.each_with_index do |entry, position|
        ShowcaseEntry.where(id: entry.id).update_all(position:, updated_at: now) unless entry.position == position
      end
    end

    def moved(player, card_season_id, position)
      publish(ShowcaseCardMoved.new(data: { player_id: player.id, card_season_id:, position: }), stream_name: stream_name(player.id))
    end
  end
end
