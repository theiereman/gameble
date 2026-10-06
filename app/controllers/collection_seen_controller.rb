# The collection's watermark (AD-26, AD-11): the collection page, once
# rendered with new cards, posts the latest gain it showed
# (collection_seen_controller.ts), and those cards are no longer new on the
# next visit. A JSON exchange: `{ "up_to": "<ISO 8601 time>" }` answers 204
# with no body; a refusal answers `{ error: { code, message } }`: 401
# sign_in_required (a visitor), 422 invalid_time (no time, or one that does
# not parse), 429 throttled.
class CollectionSeenController < ApplicationController
  RATE_LIMIT_WINDOW = 1.minute

  # The status and error code of each failure of Game::MarkCollectionSeen.
  FAILURES = {
    player_required: [ :unauthorized, "sign_in_required" ],
    invalid_time: [ :unprocessable_content, "invalid_time" ]
  }.freeze

  rate_limit to: 30, within: RATE_LIMIT_WINDOW, only: :create,
    by: -> { current_player&.id || request.remote_ip }, with: :throttled

  # POST /:locale/library/seen
  def create
    authorize :collection_seen, :create?

    result = Game::MarkCollectionSeen.new.call(player: current_player, up_to:)
    if result.success?
      head :no_content
    else
      render_failure(result.failure)
    end
  end

  private
    # The time posted, nil when missing or not an ISO 8601 time.
    def up_to
      value = params[:up_to]
      Time.zone.iso8601(value) if value.is_a?(String)
    rescue ArgumentError
      nil
    end

    def render_failure(failure)
      status, code = FAILURES.fetch(failure)
      message = failure == :player_required ? t("authorization.sign_in_required") : Game::MarkCollectionSeen.failure_message(failure)
      render_json_error(status, code, message)
    end

    def render_json_error(status, code, message)
      render json: { error: { code:, message: } }, status:
    end

    def throttled
      response.headers["Retry-After"] = RATE_LIMIT_WINDOW.to_i.to_s
      render_json_error(:too_many_requests, "throttled", t("library.seen.throttled"))
    end
end
