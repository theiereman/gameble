module BackOffice
  class ChartPublicationsController < BaseController
    rate_limit to: 20, within: 1.minute, only: %i[publish unpublish]

    def publish
      authorize [ :back_office, :chart_publication ], :publish?
      switch(Game::Market::PublishChart, :published)
    end

    def unpublish
      authorize [ :back_office, :chart_publication ], :unpublish?
      switch(Game::Market::UnpublishChart, :unpublished)
    end

    private
      def switch(operation, outcome)
        kind = params[:kind].to_s
        result = operation.new.call(player: current_player, kind:)
        return redirect_refused(operation, result, back_office_market_path) if result.failure?

        flash[:switched_chart] = kind
        redirect_to back_office_market_path(anchor: "chart-switches"), status: :see_other,
          notice: t("back_office.chart_switches.#{outcome}", chart: t("back_office.chart_switches.names.#{kind}"))
      end
  end
end
