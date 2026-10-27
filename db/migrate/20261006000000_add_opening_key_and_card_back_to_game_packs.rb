# The opening exchange: the Idempotency-Key of the request
# that opened a pack, so a lost answer or a double activation replays it, and
# the card back the player had on at the opening. Expand only:
# both columns nullable, as the packs opened before carry neither
# (their back reads as "standard"); a pack opened by the HTML form keeps no
# key. The key's unique index comes in the next migration, built
# concurrently.
class AddOpeningKeyAndCardBackToGamePacks < ActiveRecord::Migration[8.1]
  def change
    add_column :game_packs, :idempotency_key, :uuid
    add_column :game_packs, :card_back, :string
  end
end
