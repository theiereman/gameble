# Opening a pack from the attic chest and the list of its cards (CAP-4, R9).
# Packs are addressed by their token (AD-15). No reveal yet: the result page
# lists the five cards (story 3.6 brings the reveal).
class PacksController < ApplicationController
  rate_limit to: 30, within: 1.minute, only: :create,
    by: -> { current_player&.id || request.remote_ip },
    with: -> { redirect_to home_path, alert: t("packs.create.throttled"), status: :see_other }

  # POST /:locale/packs
  def create
    authorize :pack, :create?

    result = Game::OpenPack.new.call(player: current_player)
    if result.success?
      redirect_to pack_path(result.value!.token), status: :see_other
    else
      redirect_to home_path, alert: Game::OpenPack.failure_message(result.failure), status: :see_other
    end
  end

  # GET /:locale/packs/:token. Another player's pack, one not opened yet or
  # an unknown token are all not found.
  def show
    @pack = Game::OpenedPackByToken.call(current_player, params[:token])
    raise ActiveRecord::RecordNotFound if @pack.nil?

    authorize @pack, :show?, policy_class: PackPolicy
    labels = Catalog::CardSeasonLabels.call(@pack.card_season_ids, locale: I18n.locale)
    @cards = @pack.card_season_ids.map { |id| labels.fetch(id) }
  end
end
