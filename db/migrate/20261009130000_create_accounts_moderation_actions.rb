class CreateAccountsModerationActions < ActiveRecord::Migration[8.1]
  def change
    create_table :accounts_moderation_actions do |t|
      t.string :kind, null: false
      t.references :player, null: false, index: false, foreign_key: { to_table: :accounts_players }
      t.references :staff, null: false, foreign_key: { to_table: :accounts_players }
      t.text :reason
      t.datetime :created_at, null: false

      t.index :created_at
      t.index [ :player_id, :created_at ]
      t.check_constraint "kind IN ('ban', 'unban', 'dismissal')", name: "accounts_moderation_actions_kind_check"
      t.check_constraint "reason IS NULL OR kind = 'ban'", name: "accounts_moderation_actions_reason_kind_check"
      t.check_constraint "reason IS NULL OR char_length(reason) <= 500", name: "accounts_moderation_actions_reason_length_check"
    end
  end
end
