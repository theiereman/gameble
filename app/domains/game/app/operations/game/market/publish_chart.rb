module Game
  module Market
    class PublishChart < Operation
      include ChartPublishing

      def call(player:, kind:)
        step require_administrator(player)
        kind = step known_kind(kind)

        transaction do
          publication = locked_publication(kind, player)
          step publish_chart(publication, player) unless publication.published?
          publication
        end
      end

      private

      def publish_chart(publication, player)
        publication.update!(published_at: Time.current, changed_by_id: player.id)
        publish(ChartPublished.about(publication), stream_name: STREAM)
      end
    end
  end
end
