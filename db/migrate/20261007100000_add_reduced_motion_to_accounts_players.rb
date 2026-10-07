# The player's "Animations réduites" setting (EXPERIENCE.md, Reduced motion;
# AD-27, story 10.4): true forces reduced motion, false is an explicit "no",
# NULL follows the system's preference. Expand only (AD-21): nullable, not
# backfilled, so every existing player keeps following the system.
class AddReducedMotionToAccountsPlayers < ActiveRecord::Migration[8.1]
  def change
    add_column :accounts_players, :reduced_motion, :boolean
  end
end
