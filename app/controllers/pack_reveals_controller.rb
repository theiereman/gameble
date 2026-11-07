class PackRevealsController < ApplicationController
  RATE_LIMIT_WINDOW = 1.minute

  OPENING_DURATIONS = %w[touch_to_blast touch_to_first_face].freeze
  OPENING_DURATION_LIMIT_MS = 60_000
  OPENING_LAYOUTS = %w[phone narrow wide].freeze

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
      log_opening_timings
      head :no_content
    else
      render_failure(result.failure)
    end
  end

  private
    def log_opening_timings
      durations = opening_durations
      return if durations.empty?

      timings = durations.merge(opening_layout).map { |name, value| "#{name}=#{value}" }.join(" ")
      Rails.logger.info("Booster opening timings: mode=#{params[:mode]} #{timings}")
    end

    def opening_durations
      OPENING_DURATIONS.to_h { [ it, params[it] ] }.select { |_, value| opening_duration?(value) }
    end

    def opening_duration?(value)
      value.is_a?(Integer) && value >= 0 && value < OPENING_DURATION_LIMIT_MS
    end

    def opening_layout
      OPENING_LAYOUTS.include?(params[:layout]) ? { "layout" => params[:layout] } : {}
    end

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
