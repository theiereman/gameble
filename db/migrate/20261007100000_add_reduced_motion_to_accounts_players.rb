# The player's "Animations réduites" setting: true forces reduced motion,
# false is an explicit "no",
# NULL follows the system's preference. Expand only: nullable, not
# backfilled, so every existing player keeps following the system.
class AddReducedMotionToAccountsPlayers < ActiveRecord::Migration[8.1]
  def change
    add_column :accounts_players, :reduced_motion, :boolean
  end
end
