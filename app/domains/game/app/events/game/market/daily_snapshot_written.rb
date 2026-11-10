module Game
  module Market
    class DailySnapshotWritten < RubyEventStore::Event
      STREAM = "Game::Market$snapshots"

      def self.about(snapshot) = new(data: { snapshot_id: snapshot.id })
    end
  end
end
