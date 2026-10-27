module Game
  # Published when a contributor of a reached weekly goal earns its reward,
  # which then waits for the player's claim. Identifiers only:
  # data = { player_id:, week_start: "YYYY-MM-DD" }, on the player's stream
  # (Game::Operation.stream_name).
  class GoalRewardGranted < RubyEventStore::Event
  end
end
