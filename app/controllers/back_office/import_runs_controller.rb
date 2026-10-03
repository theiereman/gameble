module BackOffice
  # The Steam import runs (R1, R2, AD-19), administrators only: the list of
  # runs, starting one, watching one, resuming a failed one from its cursor
  # or abandoning the latest failed one, and rescoring the latest completed
  # one (its cards step again, after a change of the prestige formula). A run's page reloads its frame
  # every few seconds while the run is active (poller_controller.ts). Runs
  # are addressed by their token (AD-15).
  class ImportRunsController < ApplicationController
    rate_limit to: 10, within: 1.minute, only: %i[create resume rescore abandon]

    before_action :set_import_run, only: %i[show resume rescore abandon]

    def index
      authorize [ :back_office, :import_runs ], :index?
      @import_runs = Steam::LatestImportRuns.call
    end

    def show
      authorize [ :back_office, :import_runs ], :show?
      @resumable = Steam::ResumeImport.refusal(@import_run).nil?
      @rescorable = Steam::RescoreCards.refusal(@import_run).nil?
      @abandon_refusal = Steam::AbandonImport.refusal(@import_run)
    end

    def create
      authorize [ :back_office, :import_runs ], :create?

      result = Steam::StartImport.new.call
      if result.success?
        redirect_to back_office_import_run_path(result.value!), notice: t(".started")
      else
        redirect_to back_office_import_runs_path, alert: Steam::StartImport.failure_message(result.failure)
      end
    end

    def resume
      authorize [ :back_office, :import_runs ], :resume?

      result = Steam::ResumeImport.new.call(import_run_id: @import_run.id)
      if result.success?
        redirect_to back_office_import_run_path(@import_run), notice: t(".resumed")
      else
        redirect_to back_office_import_run_path(@import_run), alert: Steam::ResumeImport.failure_message(result.failure)
      end
    end

    def rescore
      authorize [ :back_office, :import_runs ], :rescore?

      result = Steam::RescoreCards.new.call(import_run_id: @import_run.id)
      if result.success?
        redirect_to back_office_import_run_path(@import_run), notice: t(".rescoring")
      else
        alert = result.failure == :run_in_progress ? t(".run_in_progress") : Steam::RescoreCards.failure_message(result.failure)
        redirect_to back_office_import_run_path(@import_run), alert:
      end
    end

    def abandon
      authorize [ :back_office, :import_runs ], :abandon?

      result = Steam::AbandonImport.new.call(import_run_id: @import_run.id)
      if result.success?
        redirect_to back_office_import_run_path(@import_run), notice: t(".abandoned")
      else
        redirect_to back_office_import_run_path(@import_run), alert: Steam::AbandonImport.failure_message(result.failure)
      end
    end

    private
      # Authorized before anything is shown: a run that does not exist is a
      # 404 for an administrator only.
      def set_import_run
        authorize [ :back_office, :import_runs ], :show?
        @import_run = Steam::ImportRunByToken.call(params[:id]) or raise ActiveRecord::RecordNotFound
      end
  end
end
