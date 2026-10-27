class ShowcasesController < ApplicationController
  def create
    authorize :showcase, :create?
    change(Game::AddToShowcase)
  end

  def update
    authorize :showcase, :update?
    params.key?(:position) ? place : move
  end

  def destroy
    authorize :showcase, :destroy?
    change(Game::RemoveFromShowcase)
  end

  private
    def place
      change(Game::PlaceShowcaseCard, position: Integer(params[:position].to_s, 10, exception: false)) do
        changed(fallback: brother_path(token: current_player.token))
      end
    end

    def move
      change(Game::MoveShowcaseCard, direction: params[:direction].to_s) do
        flash[:moved_showcase_card] = { "slug" => params[:slug], "number" => params[:number].to_s, "direction" => params[:direction].to_s } unless request.format.json?
        changed(fallback: brother_path(token: current_player.token))
      end
    end

    def change(operation, **options)
      card_season_id = Catalog::PublishedCardSeasonId.call(slug: params[:slug], season_number: Integer(params[:number], 10, exception: false))
      return not_found if card_season_id.nil?

      result = operation.new.call(player: current_player, card_season_id:, **options)
      if result.failure?
        refused(operation.failure_message(result.failure), code: result.failure.to_s)
      elsif block_given?
        yield
      else
        changed
      end
    end

    def card_path
      card_season_path(slug: params[:slug], number: params[:number])
    end

    def changed(fallback: card_path)
      respond_to do |format|
        format.turbo_stream { redirect_back_or_to fallback, status: :see_other }
        format.html { redirect_back_or_to fallback, status: :see_other }
        format.json { head :no_content }
      end
    end

    def refused(message, status: :unprocessable_content, code:)
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.append("toasts", ToastComponent.new(message:, tone: :alert)), status: }
        format.html { redirect_back_or_to card_path, alert: message, status: :see_other }
        format.json { render json: { error: { code:, message: } }, status: }
      end
    end

    def not_found
      raise ActiveRecord::RecordNotFound unless request.format.turbo_stream? || request.format.json?

      refused(t("showcases.not_found"), status: :not_found, code: "not_found")
    end
end
