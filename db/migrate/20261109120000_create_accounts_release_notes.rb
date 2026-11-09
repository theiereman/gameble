# The notes staff write for each production release, shown once to every player when that release runs, and the players who saw each one.
class CreateAccountsReleaseNotes < ActiveRecord::Migration[8.1]
  def change
    create_table :accounts_release_notes do |t|
      t.string :token, null: false, index: { unique: true }
      t.string :version, null: false, index: { unique: true }
      t.string :state, null: false, default: "draft"
      t.string :title_fr, null: false, default: ""
      t.string :title_en, null: false, default: ""
      t.text :body_fr, null: false, default: ""
      t.text :body_en, null: false, default: ""
      t.timestamps

      t.check_constraint "version ~ '^v[0-9]+\\.[0-9]+\\.[0-9]+$'", name: "accounts_release_notes_version_check"
      t.check_constraint "state = 'draft' OR state = 'ready' OR state = 'skipped'", name: "accounts_release_notes_state_check"
      t.check_constraint "char_length(title_fr) <= 80 AND char_length(title_en) <= 80 AND char_length(body_fr) <= 1500 AND char_length(body_en) <= 1500",
        name: "accounts_release_notes_length_check"
    end

    create_table :accounts_release_note_reads do |t|
      t.references :release_note, null: false, index: false, foreign_key: { to_table: :accounts_release_notes, on_delete: :cascade }
      t.references :player, null: false, foreign_key: { to_table: :accounts_players }
      t.datetime :created_at, null: false

      t.index %i[release_note_id player_id], unique: true, name: "index_accounts_release_note_reads_uniqueness"
    end
  end
end
