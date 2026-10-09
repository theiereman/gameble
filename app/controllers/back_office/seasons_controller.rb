module BackOffice
  class SeasonsController < BaseController
    rate_limit to: 10, within: 1.minute, only: :publish

    def index
      authorize [ :back_office, :seasons ], :index?
      @seasons = Catalog::SeasonSummaries.call
      @preview = Catalog::DraftPreview.call
      @import_unfinished = Steam::UnfinishedImportRun.call.present?
    end

    def show
      authorize [ :back_office, :seasons ], :show?
      @season = Catalog::SeasonScores.call(Integer(params[:number], 10)) or raise ActiveRecord::RecordNotFound
    end

    def publish
      authorize [ :back_office, :seasons ], :publish?

      if Steam::UnfinishedImportRun.call
        return redirect_to back_office_seasons_path, alert: t(".import_active")
      end

      result = Catalog::PublishSeason.new.call(number: Integer(params[:number].to_s, 10, exception: false))
      if result.success?
        redirect_to back_office_seasons_path, notice: t(".published", number: result.value!.number)
      else
        redirect_to back_office_seasons_path, alert: Catalog::PublishSeason.failure_message(result.failure)
      end
    end
  end
end
