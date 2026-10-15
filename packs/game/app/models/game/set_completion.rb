module Game
  # A set a player completed, as recorded before set tiers (Game::SetTier).
  # Nothing writes it any more; an account deletion still erases the
  # player's rows until the table is dropped.
  class SetCompletion < ApplicationRecord
    self.table_name = "game_set_completions"
  end
end
