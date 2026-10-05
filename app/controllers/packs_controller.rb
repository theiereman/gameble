# Opening a pack from the hub, and the opened pack's page (CAP-4,
# CAP-5, R9). Packs are addressed by their token (AD-15). Right after an
# opening the page mounts the reveal (the PackReveal island), once: every
# later visit, reload or back navigation shows the cards face up.
class PacksController < ApplicationController
  rate_limit to: 30, within: 1.minute, only: :create,
    by: -> { current_player&.id || request.remote_ip },
    with: -> { redirect_to home_path, alert: t("packs.create.throttled"), status: :see_other }

  # POST /:locale/packs. The flash names the opened pack for the next
  # request only; the layout never prints it.
  def create
    authorize :pack, :create?

    result = Game::OpenPack.new.call(player: current_player)
    if result.success?
      pack = result.value!
      flash[:reveal] = pack.token
      redirect_to pack_path(pack.token), status: :see_other
    else
      redirect_to home_path, alert: Game::OpenPack.failure_message(result.failure), status: :see_other
    end
  end

  # GET /:locale/packs/:token. Another player's pack, one not opened yet or
  # an unknown token are all not found. The reveal's response is never
  # stored, by the browser or by Turbo, so going back fetches the faces.
  def show
    @pack = Game::OpenedPackByToken.call(current_player, params[:token])
    raise ActiveRecord::RecordNotFound if @pack.nil?

    authorize @pack, :show?, policy_class: PackPolicy
    views = Catalog::CardViews.call(@pack.card_season_ids, locale: I18n.locale)
    @cards = @pack.card_season_ids.map { |id| views.fetch(id) }
    @strings = CardStrings.for(@cards)
    @next_pack = Game::BankSummary.call(current_player)[:available].positive?
    @reveal = flash[:reveal].present? && flash[:reveal] == @pack.token
    no_store if @reveal
  end

  private
    # The PackReveal island's props: the cards in their drawn order, and
    # every word resolved here (AD-16).
    def reveal_props
      {
        cards: @cards.map(&:to_props),
        cardStrings: @strings.to_props,
        strings: {
          cards: t("packs.show.cards"), flipAll: t("packs.show.flip_all"), next: t("packs.show.next"), previous: t("packs.show.previous"), allFlipped: t("packs.show.all_flipped"),
          progress: (1..@cards.size).map { |position| t("packs.show.progress", position:, count: @cards.size) },
          openNextPack: t("packs.show.open_next_pack"), backToHub: t("packs.show.back_to_hub"),
          failed: t("packs.show.failed"), reload: t("packs.show.reload")
        },
        openPackUrl: (packs_path if @next_pack),
        hubUrl: home_path
      }
    end
    helper_method :reveal_props
end
