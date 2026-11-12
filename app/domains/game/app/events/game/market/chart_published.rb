module Game
  module Market
    class ChartPublished < RubyEventStore::Event
      def self.about(publication) = new(data: { kind: publication.kind, player_id: publication.changed_by_id })
    end
  end
end
