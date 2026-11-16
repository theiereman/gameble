class BellReadsController < ApplicationController
  RATE_LIMIT_WINDOW = 1.minute

  rate_limit to: 60, within: RATE_LIMIT_WINDOW, only: :create,
    by: -> { current_player&.id || request.remote_ip }, with: :throttled

  def create
    authorize :bell_read, :create?

    result = Game::MarkBellRead.new.call(player: current_player, keys: params[:keys])
    head(result.success? ? :no_content : :unprocessable_content)
  end

  private
    def throttled
      response.headers["Retry-After"] = RATE_LIMIT_WINDOW.to_i.to_s
      head :too_many_requests
    end
end
