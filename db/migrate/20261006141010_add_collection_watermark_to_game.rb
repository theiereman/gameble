# The collection's NOUVEAU tag (AD-26, story 10.1): when each holding last
# gained copies, and up to when the player has seen their collection. A
# holding is new when it has copies and gained them after the watermark (any
# gain, while the watermark is NULL). Expand only (AD-21): both columns
# nullable and not backfilled, so the holdings gained before read as never
# new, and a player who never looked has no watermark.
class AddCollectionWatermarkToGame < ActiveRecord::Migration[8.1]
  def change
    add_column :game_holdings, :last_gained_at, :datetime
    add_column :game_player_states, :collection_seen_up_to, :datetime
  end
end
