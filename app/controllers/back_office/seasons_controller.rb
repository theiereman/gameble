module BackOffice
  class SeasonsController < BaseController
    rate_limit to: 10, within: 1.minute, only: %i[publish update]

    def index
      authorize [ :back_office, :seasons ], :index?
      @seasons = Catalog::SeasonSummaries.call
      @preview = Catalog::DraftPreview.call
      @unfinished_import = Steam::UnfinishedImportRun.call
    end

    def show
      authorize [ :back_office, :seasons ], :show?
      @season = Catalog::SeasonScores.call(season_number) or raise ActiveRecord::RecordNotFound
    end

    def publish
      authorize [ :back_office, :seasons ], :publish?

      if (unfinished = Steam::UnfinishedImportRun.call)
        return redirect_to back_office_seasons_path, alert: unfinished.ready? ? t(".import_awaiting_promotion") : t(".import_active")
      end

      result = Catalog::PublishSeason.new.call(number: Integer(params[:number].to_s, 10, exception: false), **season_names)
      if result.success?
        redirect_to back_office_seasons_path, notice: t(".published", number: result.value!.number)
      else
        redirect_to back_office_seasons_path, alert: Catalog::PublishSeason.refusal_message(result.failure, Catalog::DraftPreview.call)
      end
    end

    def update
      authorize [ :back_office, :seasons ], :update?
      raise ActiveRecord::RecordNotFound unless Catalog::SeasonNumberKnown.call(season_number)

      result = Catalog::RenameSeason.new.call(number: season_number, **season_names)
      if result.success?
        redirect_to back_office_season_path(season_number), notice: t(".updated", number: season_number), status: :see_other
      else
        redirect_refused Catalog::RenameSeason, result, back_office_season_path(season_number)
      end
    end

    private
      def season_number
        Integer(params[:number], 10)
      end

      def season_names
        { name_en: params[:name_en], name_fr: params[:name_fr] }
      end
  end
end
