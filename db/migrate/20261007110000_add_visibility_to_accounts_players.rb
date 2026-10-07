# The player's profile visibility (CAP-14, AD-14): public, friends_only or
# private. Expand (AD-21): a constant default with NOT NULL is a metadata-only
# change on PostgreSQL 11+, so every existing player becomes public without a
# backfill; the check constraint is added unvalidated, to be validated by the
# contract migration that follows.
class AddVisibilityToAccountsPlayers < ActiveRecord::Migration[8.1]
  def change
    add_column :accounts_players, :visibility, :string, default: "public", null: false
    add_check_constraint :accounts_players, "visibility IN ('public', 'friends_only', 'private')",
      name: "accounts_players_visibility_check", validate: false
  end
end
