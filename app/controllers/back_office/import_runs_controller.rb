module BackOffice
  class ImportRunsController < BaseController
    rate_limit to: 10, within: 1.minute, only: %i[create resume rescore abandon promote discard]

    before_action :set_import_run, only: %i[show resume rescore abandon promote discard]

    def index
      authorize [ :back_office, :import_runs ], :index?
      @import_runs = Steam::LatestImportRuns.call
    end

    def show
      authorize [ :back_office, :import_runs ], :show?
      @resumable = Steam::ResumeImport.refusal(@import_run).nil?
      @rescorable = Steam::RescoreCards.refusal(@import_run).nil?
      @abandon_refusal = Steam::AbandonImport.refusal(@import_run)
      @review = Catalog::StagedBatchReview.call(@import_run.token) if @import_run.ready?
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

    def promote
      authorize [ :back_office, :import_runs ], :promote?

      result = Steam::PromoteImport.new.call(import_run_id: @import_run.id)
      if result.success?
        redirect_to back_office_import_run_path(@import_run), notice: t(".promoted")
      else
        redirect_to back_office_import_run_path(@import_run), alert: Steam::PromoteImport.failure_message(result.failure)
      end
    end

    def discard
      authorize [ :back_office, :import_runs ], :discard?

      result = Steam::DiscardImport.new.call(import_run_id: @import_run.id)
      if result.success?
        redirect_to back_office_import_run_path(@import_run), notice: t(".discarded")
      else
        redirect_to back_office_import_run_path(@import_run), alert: Steam::DiscardImport.failure_message(result.failure)
      end
    end

    private
      def set_import_run
        authorize [ :back_office, :import_runs ], :show?
        @import_run = Steam::ImportRunByToken.call(params[:id]) or raise ActiveRecord::RecordNotFound
      end
  end
end
