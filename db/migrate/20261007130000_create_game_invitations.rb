# Friend invitations (AD-8, story 5.2): by friend code or by invite link, a
# sender asks a recipient; pending until the recipient accepts (which creates
# the friendship) or ignores. Addressed by a random token (AD-15). At most
# one pending invitation per sender and recipient.
class CreateGameInvitations < ActiveRecord::Migration[8.1]
  def change
    create_table :game_invitations do |t|
      t.string :token, null: false, index: { unique: true }
      t.references :sender, null: false, foreign_key: { to_table: :accounts_players }
      t.references :recipient, null: false, foreign_key: { to_table: :accounts_players }
      t.string :status, null: false, default: "pending"
      t.timestamps
      t.index %i[sender_id recipient_id], unique: true, where: "status = 'pending'", name: "index_game_invitations_one_pending_per_pair"
      t.check_constraint "status IN ('pending', 'accepted', 'ignored')", name: "game_invitations_status_check"
      t.check_constraint "sender_id <> recipient_id", name: "game_invitations_distinct_check"
    end
  end
end
