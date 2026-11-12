module Game
  module Market
    class UnpublishChart < Operation
      include ChartPublishing

      def call(player:, kind:)
        step require_administrator(player)
        kind = step known_kind(kind)

        transaction do
          publication = ChartPublication.lock.find_by(kind:)
          step unpublish_chart(publication, player) if publication&.published?
          publication
        end
      end

      private

      def unpublish_chart(publication, player)
        publication.update!(unpublished_at: Time.current, changed_by_id: player.id)
        publish(ChartUnpublished.about(publication), stream_name: STREAM)
      end
    end
  end
end
