class AllowTheErasureInAccountsModerationActionsKind < ActiveRecord::Migration[8.1]
  def up
    safety_assured { remove_check_constraint :accounts_moderation_actions, "kind::text = 'ban'::text OR kind::text = 'unban'::text OR kind::text = 'dismissal'::text", name: "accounts_moderation_actions_kind_check" }
    add_check_constraint :accounts_moderation_actions, "kind = 'ban' OR kind = 'unban' OR kind = 'dismissal' OR kind = 'erasure'", name: "accounts_moderation_actions_kind_values_check", validate: false
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "erasure rows are moderation history: delete them by hand if you must go back"
  end
end
