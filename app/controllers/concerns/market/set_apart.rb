module Market
  # Confier's first step when wanted copies are ticked: one copy per player who wants it is set apart for the wanted table,
  # the rest is entrusted at once, and the table opens with the set-apart copies in its address.
  module SetApart
    extend ActiveSupport::Concern

    private
      def split_wanted(posted)
        wanted = Game::Market::WantedCopies.call(current_player).index_by(&:ref)
        set_apart = posted.to_h { |ref, copies| [ ref, [ copies.to_i, wanted[ref]&.seekers.to_i ].min ] }.select { |_, copies| copies.positive? }
        rest = posted.to_h { |ref, copies| [ ref, copies.to_i - set_apart.fetch(ref, 0) ] }.select { |_, copies| copies.positive? }
        [ set_apart, rest ]
      end

      def entrust_then_choose(set_apart, rest)
        if rest.any?
          result = entrust(rest)
          return show_refusal(result.failure) if result.failure? && result.failure != :nothing_fits

          flash[:entrusted_first] = result.success? ? entrusted_first(result.value!) : nothing_fitted(rest)
        end
        redirect_to new_market_wanted_choice_path(selection: helpers.entrust_selection(set_apart)), status: :see_other
      end

      def entrusted_first(entrusted)
        refs = Game::Market::EntrustableCopies.resolve(ticked.keys).invert
        stayed = entrusted.stayed.filter_map { |line| [ refs[line.card_season_id], line.copies, line.value ] if refs.key?(line.card_season_id) }
        first_step(minted: entrusted.minted, copies: entrusted.copies, cap_left: entrusted.cap_left, stayed:)
      end

      def nothing_fitted(rest)
        settings = Game::Market::CurrentSettings.call
        copies = Game::Market::EntrustableCopies.call(current_player, settings:, refs: rest.keys, cards: false)
        first_step(minted: 0, copies: 0, cap_left: Game::Market::CapLeft.call(current_player.id, settings:),
          stayed: copies.map { [ it.ref, [ rest.fetch(it.ref), it.free ].min, it.value ] })
      end

      def first_step(minted:, copies:, cap_left:, stayed:)
        { "minted" => minted, "copies" => copies, "cap_left" => cap_left, "stayed_count" => stayed.size,
          "stayed" => stayed.first(MarketEntrustmentsHelper::RESULT_LINES) }
      end
  end
end
