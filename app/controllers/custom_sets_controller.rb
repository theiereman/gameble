class CustomSetsController < ApplicationController
  include SetAlbumLoading
  include CustomSetPicking

  throttle_player to: 20, only: %i[create update destroy], path: -> { library_path }, alert: "custom_sets.throttled"

  def show
    authorize_custom_set(:show?)
    @season = Catalog::PublishedSeason.call
    raise ActiveRecord::RecordNotFound if @season.nil?

    @custom_set = Game::CustomSetStandings.call(current_player, tokens: [ params[:token] ]).first
    raise ActiveRecord::RecordNotFound if @custom_set.nil?

    @standing = @custom_set.to_set_standing
    editions = Game::HeldGames.editions(current_player, card_ids: @custom_set.card_ids, season: @season)
    load_album_slots(album_members(@custom_set.card_ids, editions), editions, with_new: true)
    @unique = Game::HeldGames.count(current_player)
    @season_cards = Catalog::CardCount.call(@season)
  end

  def new
    authorize :custom_set, :new?
    load_picker([])
  end

  def picker
    authorize :custom_set, :picker?
    load_picker(picked_slugs)
    render :new
  end

  def create
    authorize :custom_set, :create?
    slugs = picked_slugs
    result = Game::CreateCustomSet.new.call(player: current_player, name: params[:name], card_ids: picked_card_ids(slugs))
    return redirect_to(custom_set_path(token: result.value!.token), status: :see_other) if result.success?

    @refusal = Game::CreateCustomSet.failure_message(result.failure)
    load_picker(slugs)
    render :new, status: :unprocessable_content
  end

  def edit
    @name = editable_custom_set(:edit?).name
  end

  def update
    editable_custom_set(:update?)
    result = Game::RenameCustomSet.new.call(player: current_player, token: params[:token], name: params[:name])
    return redirect_to(custom_set_path(token: params[:token]), status: :see_other) if result.success?

    @name = params[:name].is_a?(String) ? params[:name] : ""
    @refusal = Game::RenameCustomSet.failure_message(result.failure)
    render :edit, status: :unprocessable_content
  end

  def destroy
    editable_custom_set(:destroy?)
    result = Game::DeleteCustomSet.new.call(player: current_player, token: params[:token])
    return redirect_refused(Game::DeleteCustomSet, result, library_path) if result.failure?

    flash[:toast_title] = t("custom_sets.deleted.title")
    flash[:notice] = t("custom_sets.deleted.text", name: result.value!)
    redirect_to library_path, status: :see_other
  end

  private
    def authorize_custom_set(query)
      custom_set = Game::CustomSetByToken.call(params[:token])
      raise ActiveRecord::RecordNotFound if custom_set.nil? && current_player

      authorize(custom_set || :custom_set, query, policy_class: CustomSetPolicy)
      custom_set
    end

    def editable_custom_set(query)
      custom_set = authorize_custom_set(query)
      raise ActiveRecord::RecordNotFound unless custom_set.custom?

      custom_set
    end

    def album_members(card_ids, editions)
      faces = Catalog::LatestPublishedCardSeasons.call(card_ids)
      card_ids.filter_map { |card_id| [ faces[card_id], card_id ] if faces.key?(card_id) || editions.key?(card_id) }
    end
end
