module BackOffice
  class MarketClosingsController < BaseController
    include MarketPage

    rate_limit to: 10, within: 1.minute, only: :create

    def create
      authorize [ :back_office, :market_closing ], :create?

      submitted = submitted_closing
      result = Game::Market::ChangeSettings.new.call(player: current_player, settings_token: submitted[:token], close: true,
        message_fr: submitted[:message_fr], message_en: submitted[:message_en])
      if result.success?
        redirect_to back_office_market_path, notice: t(".closed"), status: :see_other
      else
        render_refused(result.failure, submitted)
      end
    end

    private
      def submitted_closing
        submitted = params[:market_closing]
        return {} unless submitted.is_a?(ActionController::Parameters)

        submitted.permit(:token, :message_fr, :message_en).to_h.symbolize_keys
      end

      def render_refused(code, submitted)
        @settings_form = settings_form_for_page
        @closing = MarketsController::Closing.new(message_fr: submitted[:message_fr], message_en: submitted[:message_en], refusal: refusal_line(code))
        render_market_page(status: :unprocessable_content)
      end

      def refusal_line(code)
        case code
        when :settings_changed then t("back_office.market_closings.stale")
        when :invalid_announcement then t("back_office.market_closings.announcement_refused")
        else Game::Market::ChangeSettings.failure_message(code)
        end
      end
  end
end
