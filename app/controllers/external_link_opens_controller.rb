class ExternalLinkOpensController < ApplicationController
  RATE_LIMIT_WINDOW = 1.minute

  rate_limit to: 60, within: RATE_LIMIT_WINDOW, only: :create,
    by: -> { current_player&.id || request.remote_ip }, with: :throttled

  def create
    authorize :external_link_open, :create?

    result = Game::MarkLinkOpened.new.call(player: current_player, link: params[:link])
    if result.success?
      head :no_content
    elsif result.failure == :unknown_link
      raise ActiveRecord::RecordNotFound
    else
      head :unprocessable_content
    end
  end

  private
    def throttled
      response.headers["Retry-After"] = RATE_LIMIT_WINDOW.to_i.to_s
      head :too_many_requests
    end
end
