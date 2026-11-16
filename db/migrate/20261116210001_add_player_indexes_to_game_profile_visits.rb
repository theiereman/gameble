class AddPlayerIndexesToGameProfileVisits < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :game_profile_visits, %i[viewer_id visited_id created_at], algorithm: :concurrently
    add_index :game_profile_visits, :visited_id, algorithm: :concurrently
  end
end
