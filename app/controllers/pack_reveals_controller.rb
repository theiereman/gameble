class PackRevealsController < ApplicationController
  RATE_LIMIT_WINDOW = 1.minute

  FAILURES = {
    player_required: [ :unauthorized, "sign_in_required" ],
    invalid_reveal_mode: [ :bad_request, "invalid_reveal_mode" ],
    pack_not_found: [ :not_found, "pack_not_found" ],
    not_latest_pack: [ :unprocessable_content, "not_latest_pack" ]
  }.freeze

  rate_limit to: 30, within: RATE_LIMIT_WINDOW, only: :create,
    by: -> { current_player&.id || request.remote_ip }, with: :throttled

  def create
    authorize :pack_reveal, :create?

    result = Game::RecordReveal.new.call(player: current_player, token: params[:token], mode: params[:mode])
    if result.success?
      head :no_content
    else
      render_failure(result.failure)
    end
  end

  private
    def render_failure(failure)
      status, code = FAILURES.fetch(failure)
      message = failure == :player_required ? t("authorization.sign_in_required") : Game::RecordReveal.failure_message(failure)
      render_json_error(status, code, message)
    end

    def render_json_error(status, code, message)
      render json: { error: { code:, message: } }, status:
    end

    def throttled
      response.headers["Retry-After"] = RATE_LIMIT_WINDOW.to_i.to_s
      render_json_error(:too_many_requests, "throttled", t("pack_reveals.create.throttled"))
    end
end
