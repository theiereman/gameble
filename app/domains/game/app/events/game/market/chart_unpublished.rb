module Game
  module Market
    class ChartUnpublished < RubyEventStore::Event
      def self.about(publication) = new(data: { kind: publication.kind, player_id: publication.changed_by_id })
    end
  end
end
