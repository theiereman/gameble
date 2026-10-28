class AllowTheErasureInAccountsModerationActionsKind < ActiveRecord::Migration[8.1]
  def change
    safety_assured { remove_check_constraint :accounts_moderation_actions, "kind::text = 'ban'::text OR kind::text = 'unban'::text OR kind::text = 'dismissal'::text", name: "accounts_moderation_actions_kind_check" }
    add_check_constraint :accounts_moderation_actions, "kind IN ('ban', 'unban', 'dismissal', 'erasure')", name: "accounts_moderation_actions_kind_values_check", validate: false
  end
end
