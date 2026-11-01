class PacksController < ApplicationController
  include PackCards
  include GoalsReachedTracking
  include GoalMarksLoading

  helper_method :goal_marks

  RATE_LIMIT_WINDOW = 1.minute

  FAILURES = {
    invalid_idempotency_key: [ :bad_request, "invalid_idempotency_key" ],
    player_required: [ :unauthorized, "sign_in_required" ],
    no_pack_available: [ :unprocessable_content, "no_pack_available" ],
    invalid_reserve: [ :bad_request, "invalid_reserve" ]
  }.freeze

  rate_limit to: 30, within: RATE_LIMIT_WINDOW, only: :create,
    by: -> { current_player&.id || request.remote_ip }, with: :throttled, unless: :replayed_key?

  def create
    authorize :pack, :create?

    respond_to do |format|
      format.html { open_from_form }
      format.json { open_from_booster }
    end
  end

  def show
    @pack = Game::OpenedPackByToken.call(current_player, params[:token])
    raise ActiveRecord::RecordNotFound if @pack.nil?

    authorize @pack, :show?, policy_class: PackPolicy
    @cards = cards_of(@pack)
    @strings = CardStrings.new
    @bank = Game::BankSummary.reserve(current_player)
    @next_pack = @bank[:openable].positive?
  end

  private

  def open_from_form
    result, reached = tracking_goals_reached(current_player) { Game::OpenPack.new.call(player: current_player, reserve: params[:reserve]) }
    if result.success?
      toast_goals_reached(reached)
      redirect_to pack_path(result.value!.token), status: :see_other
    else
      redirect_refused Game::OpenPack, result, booster_path
    end
  end

  def open_from_booster
    key = idempotency_key
    return render_failure(:invalid_idempotency_key) if key.blank?

    marks_before_opening = goal_marks
    result, reached = tracking_goals_reached(current_player) do
      Game::OpenPack.new.call(player: current_player, idempotency_key: key, reserve: params[:reserve])
    end
    if result.success?
      pack = result.value!
      render json: helpers.pack_opening_json(pack, cards: cards_of(pack), player: current_player, now: Time.current, goals_reached: reached,
        goals: marks_before_opening)
    else
      render_failure(result.failure)
    end
  end

  def render_failure(failure)
    status, code = FAILURES.fetch(failure)
    message = failure == :player_required ? t("authorization.sign_in_required") : Game::OpenPack.failure_message(failure)
    render_json_error(status, code, message)
  end

  def render_json_error(status, code, message)
    render json: { error: { code:, message: } }, status:
  end

  def idempotency_key
    request.headers["Idempotency-Key"]
  end

  def replayed_key?
    request.format.json? && Game::OpenPack.replay?(current_player, idempotency_key)
  end

  def throttled
    message = t("packs.create.throttled")
    respond_to do |format|
      format.html { redirect_to home_path, alert: message, status: :see_other }
      format.json do
        response.headers["Retry-After"] = RATE_LIMIT_WINDOW.to_i.to_s
        render_json_error(:too_many_requests, "throttled", message)
      end
    end
  end
end
