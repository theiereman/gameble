class CreateGameProfileVisits < ActiveRecord::Migration[8.1]
  def change
    create_table :game_profile_visits do |t|
      t.references :viewer, null: false, foreign_key: { to_table: :accounts_players }, index: false
      t.references :visited, null: false, foreign_key: { to_table: :accounts_players }, index: false
      t.datetime :created_at, null: false
    end
  end
end
