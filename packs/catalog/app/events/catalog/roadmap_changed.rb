module Catalog
  # Published when staff change the roadmap. Identifiers only: data =
  # { milestone_id:, story_id: (nil for a milestone change), change: }, on the
  # roadmap's stream, where `change` is milestone_updated, milestone_moved,
  # story_created, story_updated, story_moved or story_deleted.
  class RoadmapChanged < RubyEventStore::Event
  end
end
