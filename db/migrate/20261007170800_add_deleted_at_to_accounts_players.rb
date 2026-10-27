# Account deletion: a deleted player's record stays, as the
# target of the rows that name it, but anonymised: its Steam id is released
# so the player can sign up again, and `deleted_at` says when. Expand:
# a nullable column, the NOT NULL dropped from steam_id (no rewrite),
# and the check that a player has a Steam id exactly while not deleted added
# unvalidated, to be validated by the contract migration that follows.
class AddDeletedAtToAccountsPlayers < ActiveRecord::Migration[8.1]
  def change
    add_column :accounts_players, :deleted_at, :datetime
    change_column_null :accounts_players, :steam_id, true
    add_check_constraint :accounts_players, "(steam_id IS NULL) = (deleted_at IS NOT NULL)",
      name: "accounts_players_deleted_check", validate: false
  end
end
