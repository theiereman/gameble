# The trade and its cards (AD-8, story 5.4). A trade is a proposal between
# two friends: the pair (lower player id first, like a friendship), who
# proposed and who answers, and its status. Two friends have at most one
# open trade, kept by a partial unique index. Its items are the cards of
# each side with a quantity; only the offer is reserved on the proposer's
# holdings (AD-6).
class CreateGameTrades < ActiveRecord::Migration[8.1]
  def change
    create_table :game_trades do |t|
      t.references :low_player, null: false, index: false, foreign_key: { to_table: :accounts_players }
      t.references :high_player, null: false, index: false, foreign_key: { to_table: :accounts_players }
      t.references :proposer, null: false, index: false, foreign_key: { to_table: :accounts_players }
      t.references :recipient, null: false, index: false, foreign_key: { to_table: :accounts_players }
      t.string :status, null: false, default: "open"
      t.datetime :proposed_at, null: false
      t.datetime :expires_at, null: false
      t.datetime :closed_at
      t.timestamps
      t.index %i[low_player_id high_player_id], unique: true, where: "status = 'open'", name: "index_game_trades_one_open_per_pair"
      t.index %i[proposer_id status]
      t.index %i[recipient_id status]
      t.check_constraint "status IN ('open', 'cancelled', 'declined', 'accepted', 'expired')", name: "game_trades_status_check"
      t.check_constraint "low_player_id < high_player_id", name: "game_trades_order_check"
      t.check_constraint "(proposer_id = low_player_id AND recipient_id = high_player_id) OR " \
        "(proposer_id = high_player_id AND recipient_id = low_player_id)", name: "game_trades_parties_check"
    end

    create_table :game_trade_items do |t|
      t.references :trade, null: false, index: false, foreign_key: { to_table: :game_trades }
      t.string :side, null: false
      t.references :card_season, null: false, index: false, foreign_key: { to_table: :catalog_card_seasons }
      t.integer :quantity, null: false
      t.timestamps
      t.index %i[trade_id side card_season_id], unique: true
      t.index :card_season_id
      t.check_constraint "side IN ('offer', 'request')", name: "game_trade_items_side_check"
      t.check_constraint "quantity > 0", name: "game_trade_items_quantity_check"
    end
  end
end
