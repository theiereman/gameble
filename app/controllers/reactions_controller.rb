class ReactionsController < ApplicationController
  RATE_LIMIT_WINDOW = 1.minute

  rate_limit to: 60, within: RATE_LIMIT_WINDOW, only: %i[create destroy],
    by: -> { current_player&.id || request.remote_ip }, with: :throttled

  def show
    authorize :reaction, :show?
    entry = Game::VisibleFeedEntry.call(current_player, params[:token])
    raise ActiveRecord::RecordNotFound unless entry

    show_bar(entry)
  end

  def create
    authorize :reaction, :create?
    react(params[:kind].to_s)
  end

  def destroy
    authorize :reaction, :destroy?
    react(nil)
  end

  private
    def react(kind)
      result = Game::ReactToFeedEntry.new.call(player: current_player, entry_token: params[:token], kind:)
      if result.success?
        reacted(result.value!, kind)
      else
        refuse_reaction(result.failure)
      end
    end

    def reacted(entry, kind)
      respond_to do |format|
        format.turbo_stream do
          @token = entry.token
          @summary = summary_of(entry)
          @status = kind ? t("reactions.reacted", reaction: t("reactions.names.#{kind}")) : t("reactions.removed")
          render :update
        end
        format.html { redirect_back_or_to feed_path, status: :see_other }
      end
    end

    def refuse_reaction(code)
      message = Game::ReactToFeedEntry.failure_message(code)
      status = code == :entry_not_found ? :not_found : :unprocessable_content
      respond_with_alert(status, message)
    end

    def show_bar(entry)
      @token = entry.token
      @summary = summary_of(entry)
      render :show
    end

    def summary_of(entry)
      Game::FeedReactionSummaries.call([ entry.id ], viewer: current_player).fetch(entry.id)
    end

    def respond_with_alert(status, message)
      respond_to do |format|
        format.turbo_stream do
          @message = message
          render :refused, status:
        end
        format.html { redirect_back_or_to feed_path, alert: message, status: :see_other }
      end
    end

    def throttled
      response.headers["Retry-After"] = RATE_LIMIT_WINDOW.to_i.to_s
      respond_with_alert(:too_many_requests, t("reactions.throttled"))
    end
end
