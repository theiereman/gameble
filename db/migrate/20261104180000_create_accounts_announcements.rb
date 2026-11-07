# The messages staff show to every player on a red banner, at most one at a time, and the players who closed each one.
class CreateAccountsAnnouncements < ActiveRecord::Migration[8.1]
  def change
    create_table :accounts_announcements do |t|
      t.string :token, null: false, index: { unique: true }
      t.text :message_fr, null: false
      t.text :message_en, null: false
      t.boolean :shown, null: false, default: false
      t.timestamps

      t.index :shown, unique: true, where: "shown", name: "index_accounts_announcements_one_shown"
      t.check_constraint "char_length(message_fr) BETWEEN 1 AND 280 AND char_length(message_en) BETWEEN 1 AND 280",
        name: "accounts_announcements_message_length_check"
    end

    create_table :accounts_announcement_dismissals do |t|
      t.references :announcement, null: false, index: false, foreign_key: { to_table: :accounts_announcements, on_delete: :cascade }
      t.references :player, null: false, foreign_key: { to_table: :accounts_players }
      t.datetime :created_at, null: false

      t.index %i[announcement_id player_id], unique: true, name: "index_accounts_announcement_dismissals_uniqueness"
    end
  end
end
