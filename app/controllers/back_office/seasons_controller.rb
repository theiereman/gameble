module BackOffice
  # The catalog seasons (AD-5), administrators only: the list of seasons and
  # publishing the draft. The form sends the number of the draft it showed,
  # so a stale page cannot publish another draft. Publishing is refused while
  # the latest Steam import run has not completed (a failed run can still be
  # resumed), so a run never spans two seasons.
  class SeasonsController < ApplicationController
    rate_limit to: 10, within: 1.minute, only: :publish

    def index
      authorize [ :back_office, :seasons ], :index?
      @seasons = Catalog::SeasonSummaries.call
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
