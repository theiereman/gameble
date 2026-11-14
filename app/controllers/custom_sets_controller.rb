class CustomSetsController < ApplicationController
  include SetAlbumLoading
  include CustomSetEditing
  include GoalControlLoading
  include GoalMarksLoading
  include CustomSetFaces

  helper_method :goal_marks

  throttle_player to: 20, only: %i[create update destroy], path: -> { library_path }, alert: "custom_sets.throttled"

  def show
    authorize_custom_set(:show?)
    @season = Catalog::PublishedSeason.call
    raise ActiveRecord::RecordNotFound if @season.nil?

    @custom_set = Game::CustomSetStandings.call(current_player, tokens: [ params[:token] ]).first
    raise ActiveRecord::RecordNotFound if @custom_set.nil?

    @standing = @custom_set.to_set_standing
    @picks = editor_picks(@custom_set.card_ids) if @custom_set.custom?
    editions = Game::HeldGames.editions(current_player, card_ids: @custom_set.card_ids, season: @season)
    load_album_slots(custom_set_members(@custom_set.card_ids, editions), editions, viewing_owner: current_player)
    load_goal_control({ custom_set: @custom_set.token }, targets: goal_marks.targets)
    @unique = Game::HeldGames.count(current_player)
    @season_cards = Catalog::CardCount.call(@season)
  end

  def games
    authorize :custom_set, :games?
    return redirect_to(library_path) unless turbo_frame_request?

    load_games_page
  end

  def create
    authorize :custom_set, :create?
    card_ids = picked_card_ids(picked_slugs)
    result = Game::CreateCustomSet.new.call(player: current_player, name: params[:name], card_ids:)
    return redirect_to(library_path, status: :see_other) if result.success?

    refuse_edit(Game::CreateCustomSet, result.failure, card_ids, library_path)
  end

  def update
    editable_custom_set(:update?)
    card_ids = picked_card_ids(picked_slugs)
    result = Game::EditCustomSet.new.call(player: current_player, token: params[:token], name: params[:name], card_ids:)
    return redirect_to(custom_set_path(token: params[:token]), status: :see_other) if result.success?

    refuse_edit(Game::EditCustomSet, result.failure, card_ids, custom_set_path(token: params[:token]))
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
end
