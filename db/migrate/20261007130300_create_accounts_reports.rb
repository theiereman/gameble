# Reports (CAP-15, AD-14): a player reports another player's username or
# profile with one of four reasons. The reporter is kept for the staff's
# queue and never shown to the reported player. One report per reporter and
# reported player: a repeat adds nothing (Accounts::ReportPlayer).
class CreateAccountsReports < ActiveRecord::Migration[8.1]
  def change
    create_table :accounts_reports do |t|
      t.references :reporter, null: false, index: false, foreign_key: { to_table: :accounts_players }
      t.references :reported, null: false, foreign_key: { to_table: :accounts_players }
      t.string :reason, null: false
      t.timestamps

      t.index [ :reporter_id, :reported_id ], unique: true
      t.index [ :reporter_id, :created_at ]
      t.check_constraint "reason IN ('inappropriate_name', 'cheating', 'harassment', 'other')",
        name: "accounts_reports_reason_check"
    end
  end
end
