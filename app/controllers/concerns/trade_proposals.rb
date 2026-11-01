module TradeProposals
  extend ActiveSupport::Concern

  INSUFFICIENT = %i[requested_cards_unavailable insufficient_copies request_exceeds_holdings].freeze

  private
    def befriended(token)
      friend = Accounts::PlayerByToken.call(token)
      friend if befriended?(friend)
    end

    def befriended?(friend)
      friend.present? && !friend.removed? && Game::FriendshipBetween.call(current_player, friend)
    end

    def sent_sides(friend)
      own = Game::HeldCopies.call(current_player).keys
      theirs = Game::HeldCopies.call(friend).keys
      cards = Catalog::CardViews.call(own + theirs, locale: I18n.locale)
      offer = quantities(params[:give], own, cards)
      request = quantities(params[:take], theirs, cards)

      if offer.nil? then Dry::Monads::Failure(:invalid_offer)
      elsif request.nil? then Dry::Monads::Failure(:invalid_request)
      else Dry::Monads::Success({ offer:, request: })
      end
    end

    def quantities(fields, held, cards)
      fields = fields.respond_to?(:to_unsafe_h) ? fields.to_unsafe_h : {}
      ids = held.filter_map { |id| (view = cards[id]) && [ helpers.trade_card_key(view), id ] }.to_h
      fields.each_with_object({}) do |(key, value), side|
        id = ids[key.to_s] or return
        value = value.to_s.strip
        side[id] = value unless value.empty? || value == "0"
      end
    end

    def toast(title, text)
      flash[:toast_title] = title
      flash[:notice] = text
    end

    def refused(code, friend = nil)
      message = Game::Operation.failure_message(code, name: (helpers.friend_name(friend) if friend))
      show_refusal message, title: (t("trades.insufficient") if INSUFFICIENT.include?(code))
    end

    def show_refusal(message, title: nil)
      flash[:trade_error] = message
      flash[:toast_title] = title if title
      flash[:alert] = message
    end
end
