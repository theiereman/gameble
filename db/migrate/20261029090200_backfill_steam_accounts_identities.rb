class BackfillSteamAccountsIdentities < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  BATCH_SIZE = 10_000

  def up
    after_id = 0
    while (last_id = identity_batch_after(after_id))
      after_id = last_id
    end
  end

  def down
  end

  private

  def identity_batch_after(after_id)
    ids = select_values(<<~SQL.squish)
      SELECT id FROM accounts_players WHERE id > #{Integer(after_id)} ORDER BY id LIMIT #{BATCH_SIZE}
    SQL
    return if ids.empty?

    safety_assured do
      execute <<~SQL.squish
        INSERT INTO accounts_identities (player_id, provider, uid, created_at, updated_at)
        SELECT id, 'steam', steam_id, created_at, NOW()
        FROM accounts_players
        WHERE id >= #{Integer(ids.first)} AND id <= #{Integer(ids.last)} AND steam_id IS NOT NULL
        ON CONFLICT (provider, uid) DO NOTHING
      SQL
    end
    ids.last
  end
end
