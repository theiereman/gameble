module Catalog
  # Published when the automatic pass creates roadmap milestones for epics
  # that had none. Identifiers only: data = { milestone_ids: }, on the
  # roadmap's stream.
  class RoadmapMilestonesCreated < RubyEventStore::Event
  end
end
