module Game
  module Market
    module ChartPublishing
      include RequiresAdministrator

      STREAM = "Game::Market$charts"

      private

      def known_kind(kind) = ChartPublication::KINDS.include?(kind.to_s) ? Success(kind.to_s) : Failure(:unknown_chart)

      def locked_publication(kind, player)
        now = Time.current
        ChartPublication.insert_all([ { kind:, changed_by_id: player.id, created_at: now, updated_at: now } ], unique_by: :kind)
        ChartPublication.lock.find_by!(kind:)
      end
    end
  end
end
