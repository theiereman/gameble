module Game
  # Published when a contributor of a reached weekly goal receives the reward
  # pack (CAP-12, AD-10), for the card backs to come (epic 9). Identifiers
  # only: data = { player_id:, pack_id:, week_start: "YYYY-MM-DD" }, on the
  # player's stream (Game::Operation.stream_name).
  class GoalRewardGranted < RubyEventStore::Event
  end
end
