# The friend code and the friendship (AD-8, story 5.1). A friend code is one
# per player, purely random (XXXX-XXXX), unique. A friendship is one row per
# pair, the lower player id first; two ordered pairs cannot both exist.
class CreateGameFriendCodesAndFriendships < ActiveRecord::Migration[8.1]
  def change
    create_table :game_friend_codes do |t|
      t.references :player, null: false, index: { unique: true }, foreign_key: { to_table: :accounts_players }
      t.string :code, null: false
      t.timestamps
      t.index :code, unique: true
      t.check_constraint "code ~ '^[2-9A-HJKMNP-Z]{4}-[2-9A-HJKMNP-Z]{4}$'", name: "game_friend_codes_code_check"
    end

    create_table :game_friendships do |t|
      t.references :low_player, null: false, index: false, foreign_key: { to_table: :accounts_players }
      t.references :high_player, null: false, foreign_key: { to_table: :accounts_players }
      t.timestamps
      t.index %i[low_player_id high_player_id], unique: true
      t.check_constraint "low_player_id < high_player_id", name: "game_friendships_order_check"
    end
  end
end
