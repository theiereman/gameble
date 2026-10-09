class StripRemoteIpFromEventStoreMetadata < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  BATCH_SIZE = 10_000

  def up
    last_id = select_value("SELECT max(id) FROM event_store_events")
    return unless last_id

    first_id = select_value("SELECT min(id) FROM event_store_events")
    (first_id..last_id).step(BATCH_SIZE) { |from| strip_remote_ip(from...(from + BATCH_SIZE)) }
  end

  def down
  end

  private

  # The JSON client also records each metadata key's type under types.metadata.
  def strip_remote_ip(ids)
    safety_assured do
      execute <<~SQL.squish
        UPDATE event_store_events
        SET metadata = (metadata - 'remote_ip') #- '{types,metadata,remote_ip}'::text[]
        WHERE id >= #{Integer(ids.begin)} AND id < #{Integer(ids.end)}
          AND metadata ? 'remote_ip'
      SQL
    end
  end
end
