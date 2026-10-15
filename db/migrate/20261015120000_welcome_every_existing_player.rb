class WelcomeEveryExistingPlayer < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  BATCH_SIZE = 10_000

  def up
    after_id = 0
    while (last_id = welcome_batch_after(after_id))
      after_id = last_id
    end
  end

  def down
  end

  private

  def welcome_batch_after(after_id)
    ids = select_values(<<~SQL.squish)
      SELECT id FROM accounts_players WHERE id > #{Integer(after_id)} ORDER BY id LIMIT #{BATCH_SIZE}
    SQL
    return if ids.empty?

    safety_assured do
      execute <<~SQL.squish
        UPDATE accounts_players
        SET welcome_pending = TRUE
        WHERE id >= #{Integer(ids.first)} AND id <= #{Integer(ids.last)}
          AND deleted_at IS NULL AND NOT welcome_pending
      SQL
    end
    ids.last
  end
end
