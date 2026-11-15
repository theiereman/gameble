class ExchangeTabsController < ApplicationController
  RATE_LIMIT_WINDOW = 1.minute

  FAILURES = {
    player_required: [ :unauthorized, "sign_in_required" ],
    unknown_tab: [ :unprocessable_content, "unknown_tab" ]
  }.freeze

  rate_limit to: 30, within: RATE_LIMIT_WINDOW, only: :create,
    by: -> { current_player&.id || request.remote_ip }, with: :throttled

  def create
    authorize :exchange_tab, :create?

    result = Game::KeepExchangesTab.new.call(player: current_player, tab: params[:tab])
    if result.success?
      head :no_content
    else
      render_failure(result.failure)
    end
  end

  private
    def render_failure(failure)
      status, code = FAILURES.fetch(failure)
      message = failure == :player_required ? t("authorization.sign_in_required") : Game::KeepExchangesTab.failure_message(failure)
      render_json_error(status, code, message)
    end

    def render_json_error(status, code, message)
      render json: { error: { code:, message: } }, status:
    end

    def throttled
      response.headers["Retry-After"] = RATE_LIMIT_WINDOW.to_i.to_s
      render_json_error(:too_many_requests, "throttled", t("exchanges.tabs.throttled"))
    end
end
