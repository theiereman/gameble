module Steam
  # Promotes the ready import run: its staged cards replace the draft
  # season's card-seasons in one transaction (Catalog::PromoteStagedBatch),
  # and the run is promoted. The draft can then be published.
  #
  # When the season the run began on was published since, the batch is stale:
  # it is discarded, the run is abandoned and the call fails with
  # stale_batch.
  #
  #   Steam::PromoteImport.new.call(import_run_id: run.id)
  #   # => Success(run) | Failure(:not_found) | Failure(:not_ready)
  #   #    | Failure(:empty_batch) | Failure(:stale_batch)
  class PromoteImport < ApplicationOperation
    def call(import_run_id:)
      stale = false
      run = transaction do
        run = step lock_run(import_run_id)
        step require_ready(run)
        promotion = Catalog::PromoteStagedBatch.new.call(batch_token: run.token, season_number: run.season_number)
        if promotion.failure? && promotion.failure == :stale_batch
          stale = true
          step abandon(run)
        else
          step promotion
          run.update!(status: :promoted)
          step publish(ImportRunPromoted.new(data: { import_run_id: run.id }), stream_name: ImportRun.stream_name(run.id))
        end
        run
      end

      step Failure(:stale_batch) if stale
      run
    end

    private

    def lock_run(import_run_id)
      run = ImportRun.lock.find_by(id: import_run_id)
      run ? Success(run) : Failure(:not_found)
    end

    def require_ready(run)
      run.ready? ? Success(run) : Failure(:not_ready)
    end

    def abandon(run)
      step Catalog::DiscardStagedBatch.new.call(batch_token: run.token)
      run.update!(status: :abandoned)
      publish(ImportRunAbandoned.new(data: { import_run_id: run.id }), stream_name: ImportRun.stream_name(run.id))
    end
  end
end
