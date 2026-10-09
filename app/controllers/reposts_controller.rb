class RepostsController < ApplicationController
  RATE_LIMIT_WINDOW = 1.minute

  rate_limit to: 30, within: RATE_LIMIT_WINDOW, only: :create,
    by: -> { current_player&.id || request.remote_ip }, with: :throttled

  def create
    authorize :repost, :create?

    card_season_id = Catalog::PublishedCardSeasonId.call(slug: params[:slug], season_number: Integer(params[:number], 10, exception: false))
    return not_found if card_season_id.nil?

    result = Game::RepostCard.new.call(player: current_player, card_season_id:)
    if result.success?
      answer(:ok, :notice, t(".reposted"))
    else
      answer(:unprocessable_content, :alert, Game::RepostCard.failure_message(result.failure), code: result.failure.to_s)
    end
  end

  private
    def answer(status, tone, message, code: nil)
      respond_to do |format|
        format.turbo_stream do
          @message = message
          @tone = tone
          render :create, status:
        end
        format.html { redirect_back_or_to card_season_path(slug: params[:slug], number: params[:number]), tone => message, status: :see_other }
        format.json { render json: code ? { error: { code:, message: } } : { message: }, status: }
      end
    end

    def not_found
      raise ActiveRecord::RecordNotFound unless request.format.turbo_stream? || request.format.json?

      answer(:not_found, :alert, t("reposts.create.not_found"), code: "not_found")
    end

    def throttled
      response.headers["Retry-After"] = RATE_LIMIT_WINDOW.to_i.to_s
      answer(:too_many_requests, :alert, t("reposts.create.throttled"), code: "throttled")
    end
end
