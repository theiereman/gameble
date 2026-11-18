# What players write about a feature staff asked them to test, read in the back office by feature.
class CreateAccountsFeedbacks < ActiveRecord::Migration[8.1]
  def change
    create_table :accounts_feedbacks do |t|
      t.string :token, null: false, index: { unique: true }
      t.references :player, null: false, foreign_key: { to_table: :accounts_players }
      t.string :feature, null: false
      t.text :message, null: false
      t.timestamps

      t.index %i[feature created_at]
      t.check_constraint "char_length(message) BETWEEN 1 AND 1000", name: "accounts_feedbacks_message_length_check"
    end
  end
end
