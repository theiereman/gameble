module Steam
  # Fails a running import run (AD-19): the error is appended to the run's
  # errors (the latest ImportRun::ERROR_LIMIT are kept) and the run stops
  # where its cursor is, ready to be resumed. The message must already be
  # free of the API key; Steam::WebApi redacts it from its errors.
  #
  #   Steam::FailImport.new.call(import_run_id: run.id, error: "Steam::WebApi::Error: ...")
  #   # => Success(run) | Failure(:not_found) | Failure(:not_running)
  class FailImport < ApplicationOperation
    MESSAGE_LIMIT = 500

    def call(import_run_id:, error:)
      transaction do
        run = step lock_run(import_run_id)
        step require_running(run)
        run.update!(
          status: :failed,
          finished_at: Time.current,
          error_messages: (run.error_messages + [ { "at" => Time.current.utc.iso8601, "message" => error.to_s.truncate(MESSAGE_LIMIT) } ]).last(ImportRun::ERROR_LIMIT)
        )
        step publish(ImportRunFinished.new(data: { import_run_id: run.id, status: "failed" }), stream_name: ImportRun.stream_name(run.id))
        run
      end
    end

    private

    def lock_run(import_run_id)
      run = ImportRun.lock.find_by(id: import_run_id)
      run ? Success(run) : Failure(:not_found)
    end

    def require_running(run)
      run.running? ? Success(run) : Failure(:not_running)
    end
  end
end
