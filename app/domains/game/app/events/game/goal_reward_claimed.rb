module Game
  # Published when a player claims a weekly goal reward and its reward pack
  # joins their reserve. Identifiers only:
  # data = { player_id:, pack_id:, week_start: "YYYY-MM-DD" }, on the player's
  # stream (Game::Operation.stream_name).
  class GoalRewardClaimed < RubyEventStore::Event
  end
end
