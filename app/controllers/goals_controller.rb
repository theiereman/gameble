class GoalsController < ApplicationController
  include GoalControlLoading

  CUSTOM_SET_TOKEN = /\A[1-9A-HJ-NP-Za-km-z]{24}\z/

  throttle_player to: 20, only: %i[create destroy], path: -> { album_path }, alert: "goals.throttled"

  def create
    authorize :goal, :create?
    answer(Game::AddGoal, Game::AddGoal.new.call(player: current_player, **aim))
  end

  def destroy
    authorize :goal, :destroy?
    answer(Game::RemoveGoal, Game::RemoveGoal.new.call(player: current_player, **aim))
  end

  private
    def aim
      params.key?(:custom_set) ? { custom_set: text_param(:custom_set).to_s } : { kind: text_param(:kind), key: text_param(:key) }
    end

    def text_param(name)
      params[name] if params[name].is_a?(String)
    end

    def answer(operation, result)
      refused = result.failure? && result.failure == :too_many_goals
      message = operation.failure_message(result.failure) if result.failure? && !refused
      respond_to do |format|
        format.turbo_stream { render turbo_stream: control_stream(refused, message), status: message ? :unprocessable_content : :ok }
        format.html do
          flash[:goal_refused] = true if refused
          flash[:alert] = message if message
          redirect_to album_path, status: :see_other
        end
      end
    end

    def control_stream(refused, message)
      return turbo_stream.append("toasts", ToastComponent.new(message:, tone: :alert)) if message

      load_goal_control(aim)
      turbo_stream.replace("set-album-goal", partial: "goals/control", locals: { aim: @goal_aim, goal: @goal, refused: }, method: :morph)
    end

    def album_path
      custom_set = text_param(:custom_set)
      if custom_set&.match?(CUSTOM_SET_TOKEN)
        custom_set_path(token: custom_set)
      elsif game_set_aimed?
        library_set_path(kind: params[:kind], key: params[:key])
      else
        library_path
      end
    end

    def game_set_aimed?
      key = text_param(:key)
      Catalog::SetKind::ALL.include?(text_param(:kind)) && key&.match?(Catalog::Set::KEY_FORMAT)
    end
end
