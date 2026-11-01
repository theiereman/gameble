module CustomSetEditing
  extend ActiveSupport::Concern

  GAMES_PAGE = 48
  LAST_PAGE = 1_000
  GAME_STATES = %w[all owned missing picked].freeze
  HELD_STATES = %w[owned missing].freeze
  REFUSAL = "custom-set-editor-refusal".freeze

  EditorGame = Data.define(:card, :owned)

  private
    def picked_slugs
      Array(params[:games]).grep(String).uniq.first(Game::CustomSet::GAMES.max + 1)
    end

    def picked_card_ids(slugs)
      ids = Catalog::PublishedCardIds.by_slug(slugs)
      slugs.map { ids[it] }
    end

    def editor_picks(card_ids)
      slugs = Catalog::PublishedCardIds.slugs(card_ids)
      card_ids.filter_map { slugs[it] }
    end

    def load_games_page
      @state = GAME_STATES.include?(params[:state]) ? params[:state] : GAME_STATES.first
      @query = params[:q].is_a?(String) ? params[:q].strip.first(Catalog::CollectionGrid::MAX_QUERY) : ""
      @picked = @state == "picked" ? picked_slugs : []
      @page = params[:page].to_i.clamp(1, LAST_PAGE)
      rows = games_relation.offset((@page - 1) * GAMES_PAGE).limit(GAMES_PAGE + 1).pluck(:id, :card_id)
      @more = rows.size > GAMES_PAGE
      @games = editor_games(rows.first(GAMES_PAGE))
    end

    def games_relation
      picked = picked_card_ids(@picked).compact if @state == "picked"
      faces = Catalog::LatestPublishedCardSeasons.faces(query: @query, locale: I18n.locale, picked:)
      HELD_STATES.include?(@state) ? Game::CollectionStates.call(current_player, faces, states: [ @state ]) : faces
    end

    def editor_games(rows)
      views = Catalog::CardViews.call(rows.map(&:first), locale: I18n.locale)
      held = Game::HeldGames.call(current_player.id, card_ids: rows.map(&:last))
      rows.filter_map { |id, card_id| EditorGame.new(card: views[id], owned: held.key?(card_id)) if views.key?(id) }
    end

    def refuse_edit(operation, code, card_ids, fallback)
      message = operation.failure_message(code, **refusal_values(code, card_ids))
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.update(REFUSAL, ERB::Util.html_escape(message)), status: :unprocessable_content }
        format.html { redirect_to fallback, alert: message, status: :see_other }
      end
    end

    def refusal_values(code, card_ids)
      code == :too_few_games ? { count: Game::CustomSet::GAMES.min - card_ids.compact.uniq.size } : {}
    end
end
