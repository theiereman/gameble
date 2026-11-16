module Game
  # Notes the first time a player opens one of the game's outbound links.
  class MarkLinkOpened < Operation
    COLUMNS = { "source_code" => :source_code_opened_at, "support" => :support_opened_at }.freeze

    def call(player:, link:, now: Time.current)
      player = step require_player(player)
      column = step known(link)

      transaction do
        PlayerState.insert({ player_id: player.id }, unique_by: :player_id)
        first = PlayerState.where(player_id: player.id, column => nil).update_all(column => now, updated_at: now).positive?
        step publish(LinkOpened.new(data: { player_id: player.id, link: }), stream_name: stream_name(player.id)) if first
        first
      end
    end

    private

    def known(link)
      COLUMNS.key?(link) ? Success(COLUMNS.fetch(link)) : Failure(:unknown_link)
    end
  end
end
