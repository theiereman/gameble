# Opening a pack, and the opened pack's page (CAP-4, CAP-5, R9). Packs are
# addressed by their token (AD-15).
#
# The opening answers two ways. The booster screen's exchange (JSON)
# sends an `Idempotency-Key` header,
# a UUID per activation: the answer carries the pack, its cards with their
# faces, the bank, the server time and the per-tier counts before the
# opening, and the same key answers the same pack again without opening
# another (a lost answer, a double activation), even once the reserve is
# empty or the rate limit reached. The rate limit only exempts a key already
# committed: a duplicate sent before the first answer commits is counted,
# and at the limit gets 429; its retry after Retry-After replays the pack.
# A refusal answers
# `{ error: { code, message } }`: 400 invalid_idempotency_key (no key, or not
# a UUID), 401 sign_in_required, 422 no_pack_available, 429 throttled. The
# booster screen's form (HTML), its fallback without JavaScript, is
# redirected to the pack's page, which shows the cards face up: "my last
# booster"; a refusal goes back to the booster screen with its reason.
class PacksController < ApplicationController
  include PackCards

  # The rate limit's window, also the JSON answer's Retry-After.
  RATE_LIMIT_WINDOW = 1.minute

  # The status and error code of each refusal of the opening, in JSON.
  FAILURES = {
    invalid_idempotency_key: [ :bad_request, "invalid_idempotency_key" ],
    player_required: [ :unauthorized, "sign_in_required" ],
    no_pack_available: [ :unprocessable_content, "no_pack_available" ]
  }.freeze

  rate_limit to: 30, within: RATE_LIMIT_WINDOW, only: :create,
    by: -> { current_player&.id || request.remote_ip }, with: :throttled, unless: :replayed_key?

  # POST /:locale/packs
  def create
    authorize :pack, :create?

    respond_to do |format|
      format.html { open_from_form }
      format.json { open_from_booster }
    end
  end

  # GET /:locale/packs/:token: the pack's cards face up. Another player's
  # pack, one not opened yet or an unknown token are all not found.
  def show
    @pack = Game::OpenedPackByToken.call(current_player, params[:token])
    raise ActiveRecord::RecordNotFound if @pack.nil?

    authorize @pack, :show?, policy_class: PackPolicy
    @cards = cards_of(@pack)
    @strings = CardStrings.new
    # The reserve, read once: the top bar's packs chip reuses it.
    @bank = Game::BankSummary.reserve(current_player)
    @next_pack = @bank[:available].positive?
  end

  private

  def open_from_form
    result = Game::OpenPack.new.call(player: current_player)
    if result.success?
      redirect_to pack_path(result.value!.token), status: :see_other
    else
      redirect_to booster_path, alert: Game::OpenPack.failure_message(result.failure), status: :see_other
    end
  end

  def open_from_booster
    key = idempotency_key
    return render_failure(:invalid_idempotency_key) if key.blank?

    result = Game::OpenPack.new.call(player: current_player, idempotency_key: key)
    if result.success?
      pack = result.value!
      render json: helpers.pack_opening_json(pack, cards: cards_of(pack), player: current_player, now: Time.current)
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

  # A JSON request whose key a pack of the player's already carries: it
  # replays that pack, so the rate limit does not count it.
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
