class RelaxAccountsPlayersDeletedCheck < ActiveRecord::Migration[8.1]
  def up
    safety_assured { remove_check_constraint :accounts_players, name: "accounts_players_deleted_check" }
    add_check_constraint :accounts_players, "deleted_at IS NULL OR steam_id IS NULL",
      name: "accounts_players_deleted_no_steam_id_check", validate: false
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "players without a Steam id exist once this ran"
  end
end
