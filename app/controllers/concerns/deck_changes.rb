# The deck editor's saves: JSON answers, a refusal by its code and message, at most sixty changes a minute per player.
module DeckChanges
  extend ActiveSupport::Concern

  class_methods do
    def limit_deck_changes(only:)
      rate_limit to: 60, within: 1.minute, only:, scope: "deck_changes", by: -> { current_player&.id || request.remote_ip },
        with: -> { refuse_change(:throttled, t("decks.throttled"), status: :too_many_requests) }
    end
  end

  private
    def owned_deck(query)
      deck = Game::DeckByToken.call(params[:token])
      return authorize(deck || :deck, query, policy_class: DeckPolicy) if deck || current_player.nil?
      raise ActiveRecord::RecordNotFound unless request.format.json?

      authorize(:deck, :create?, policy_class: DeckPolicy)
      nil
    end

    def answer_change(result, operation)
      return render(json: yield(result.value!)) if result.success?

      refuse_change(result.failure, operation.failure_message(result.failure))
    end

    def refuse_change(code, message, status: :unprocessable_content)
      render json: { error: { code: code.to_s, message: } }, status:
    end
end
