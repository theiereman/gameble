module BackOffice
  class MarketSettingsController < BaseController
    include MarketPage

    rate_limit to: 10, within: 1.minute, only: :create

    def create
      authorize [ :back_office, :market_setting ], :create?

      submitted = submitted_settings
      form = MarketSettingsForm.from_params(submitted, settings: Game::Market::CurrentSettings.call)
      result = Game::Market::ChangeSettings.new.call(player: current_player, settings_token: submitted[:token], candidate: form.candidate,
        message_fr: form.message_fr, message_en: form.message_en)
      if result.success?
        redirect_to back_office_market_path, notice: t("back_office.market_settings.saved"), status: :see_other
      else
        render_refused(result.failure, submitted)
      end
    end

    private
      def submitted_settings
        submitted = params[:market_settings]
        return {} unless submitted.is_a?(ActionController::Parameters)

        submitted.permit(*Game::Market::SettingsRules::EDITABLE, :token, :message_fr, :message_en).to_h.symbolize_keys
      end

      def render_refused(code, submitted)
        @settings_form = refused_form(code, submitted)
        @settings_form&.refusal = refusal_line(code)
        render_market_page(status: :unprocessable_content)
      end

      def refused_form(code, submitted)
        if code == :invalid_settings
          settings = Game::Market::FindSettings.call(submitted[:token])
          MarketSettingsForm.from_params(submitted, settings:).check if settings
        elsif (current = Game::Market::CurrentSettings.call)
          MarketSettingsForm.from_params(submitted, settings: current)
        end
      end

      def refusal_line(code)
        case code
        when :settings_changed then t("back_office.market_settings.stale")
        when :invalid_settings then t("back_office.market_settings.invalid")
        when :invalid_announcement then t("back_office.market_settings.announcement_refused")
        else Game::Market::ChangeSettings.failure_message(code)
        end
      end
  end
end
