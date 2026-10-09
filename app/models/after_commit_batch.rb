class AfterCommitBatch
  def initialize(key, &deliver)
    @key = key
    @deliver = deliver
  end

  def add(items)
    return if items.empty?

    transaction = ApplicationRecord.current_transaction
    return @deliver.call(items) unless transaction.open?

    batches = ActiveSupport::IsolatedExecutionState[@key] ||= {}
    uuid = transaction.uuid
    if batches.key?(uuid)
      batches[uuid].concat(items)
    else
      batches[uuid] = batch = items.dup
      transaction.after_commit do
        batches.delete(uuid)
        @deliver.call(batch)
      end
      transaction.after_rollback { batches.delete(uuid) }
    end
  end
end
