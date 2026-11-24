module Market
  # The entrusting screen's second step: one line per wanted copy set apart, sold to an order, put up at auction or entrusted in one validation.
  class WantedChoicesController < ApplicationController
    Posted = Data.define(:ref, :copies, :choice, :orders, :starting_price, :duration_hours)

    PRICE_FIELDS = { invalid_price: :start, start_below_minimum: :start, invalid_duration: :duration }.freeze

    throttle_player to: 10, only: :create, path: -> { new_market_wanted_choice_path(selection: posted_selection) },
      alert: "market.wanted_choices.create.throttled"

    def new
      authorize %i[market wanted_choice], :new?
      load_table
      return redirect_to(market_path, status: :see_other, notice: entrusted_first_notice) if @lines.empty?

      @first = first_step(flash[:entrusted_first])
      @focus = "market-wanted-heading"
    end

    def create
      authorize %i[market wanted_choice], :create?
      load_table
      return entrust_all if params[:all].to_s == "1"

      result = Game::Market::ApplyWantedChoices.new.call(player: current_player, lines: posted_lines.map { operation_line(it) },
        settings_token: params[:settings].to_s)
      result.success? ? show_applied(result.value!) : refuse_choices(*Array(result.failure))
    end

    private
      def load_table
        @settings = Game::Market::CurrentSettings.call
        @open = @settings&.open.present?
        @suspended = Game::Market::MarketState.call(@settings).suspended?
        @lines = @settings ? Game::Market::WantedTable.call(current_player, copies: selected_copies, settings: @settings) : []
        @cards = Catalog::CardViews.call(@lines.map(&:card_season_id), locale: I18n.locale)
        @names = Game::Market::CardNames.call(@lines.map(&:card_season_id))
        @cap_left = @settings ? Game::Market::CapLeft.call(current_player.id, settings: @settings) : 0
        @available = Game::Market::Balance.call(current_player).available
        @posted = {}
      end

      def posted_selection = params[:selection].is_a?(String) ? params[:selection] : ""

      def selected_copies
        pairs = posted_selection.split(EntrustmentsController::SELECTION_SEPARATOR).filter_map { EntrustmentsController::SELECTION_PAIR.match(it)&.captures }
        ids = Game::Market::EntrustableCopies.resolve(pairs.map(&:first))
        pairs.each_with_object(Hash.new(0)) { |(ref, copies), counts| counts[ids[ref]] += copies.to_i if ids.key?(ref) }
      end

      def entrusted_first_notice
        entrusted = flash[:entrusted_first]
        t("market.wanted_choices.new.first", count: entrusted["copies"].to_i, amount: helpers.picoins(entrusted["minted"].to_i)) if entrusted.is_a?(Hash)
      end

      def first_step(entrusted)
        return unless entrusted.is_a?(Hash)

        ids = Game::Market::EntrustableCopies.resolve(entrusted["stayed"].map(&:first))
        names = Game::Market::CardNames.call(ids.values)
        stayed = entrusted["stayed"].filter_map do |ref, copies, value|
          name = names[ids[ref]]
          [ name.title, name.season_number, copies, value ] if name
        end
        entrusted.slice("minted", "copies", "cap_left", "stayed_count").symbolize_keys.merge(stayed:)
      end

      # The posted lines in table order; a field Rack could not read as a line is an empty one, for the operation to refuse.
      def posted_lines
        @posted_lines ||= begin
          raw = params[:lines].respond_to?(:to_unsafe_h) ? params[:lines].to_unsafe_h : {}
          raw.sort_by { |index, _| index.to_i }.map { |_, line| posted_line(line.is_a?(Hash) ? line : {}) }
        end
      end

      def posted_line(line)
        orders = line["orders"].is_a?(Array) ? line["orders"].map(&:to_s) : []
        Posted.new(ref: line["ref"].to_s, copies: line["copies"].to_s, choice: line["choice"].to_s, orders:, starting_price: line["starting_price"].to_s,
          duration_hours: line["duration_hours"].to_s)
      end

      def posted_ids = @posted_ids ||= Game::Market::EntrustableCopies.resolve(posted_lines.map(&:ref))

      def operation_line(line)
        { card_season_id: posted_ids[line.ref], copies: line.copies, choice: line.choice, order_tokens: line.orders, starting_price: line.starting_price,
          duration_hours: line.duration_hours }
      end

      def entrust_all
        lines = posted_lines.filter_map { |line| [ posted_ids[line.ref], line.copies ] if posted_ids.key?(line.ref) }
        result = Game::Market::EntrustCards.new.call(player: current_player, lines:, settings_token: params[:settings].to_s)
        return refuse_choices(result.failure) if result.failure?

        entrusted = result.value!
        done t("market.wanted_choices.create.entrusted_all", copies: t("market.entrustments.result.copies", count: entrusted.copies),
          amount: helpers.picoins(entrusted.minted))
      end

      def show_applied(applied)
        landed = (applied.sold + applied.listed + applied.entrusted).map(&:line).uniq.size
        received = applied.sold.sum(&:received) + applied.entrusted.sum(&:minted)
        amount = helpers.picoins(received)
        done landed == posted_lines.size ? t("market.wanted_choices.create.applied", count: landed, amount:)
          : t("market.wanted_choices.create.applied_partial", applied: landed, count: posted_lines.size, amount:)
      end

      # The table has served its purpose: back to the market, which says what happened.
      def done(notice)
        flash[:notice] = notice
        respond_to do |format|
          format.turbo_stream { render turbo_stream: helpers.turbo_stream_action_tag("gameble-visit", location: market_path) }
          format.html { redirect_to market_path, status: :see_other }
        end
      end

      def refuse_choices(code, details = [])
        return redirect_to(market_path, status: :see_other, alert: Game::Market::ApplyWantedChoices.failure_message(code)) if @lines.empty?

        @posted = posted_lines.index_by(&:ref)
        case code
        when :best_order_changed then flag_changed(details)
        when :invalid_choices then flag_fields(details)
        else @dock_refusal = Game::Market::ApplyWantedChoices.failure_message(code)
        end
        @focus ||= "wanted-dock-refusal"
        answer(status: :unprocessable_content)
      end

      def flag_changed(changes)
        @changed = changes.filter_map { |change| (line = posted_lines[change.line]) && drawn?(line.ref) && [ line.ref, changed_reason(line, change.order) ] }.to_h
        titles = @changed.keys.filter_map { @names[posted_ids[it]]&.title }
        @dock_refusal = if @changed.any?
          t("market.wanted_choices.new.changed", count: @changed.size, cards: titles.join(", "))
        else
          Game::Market::ApplyWantedChoices.failure_message(:best_order_changed)
        end
        first = @lines.index { @changed.key?(it.ref) }
        @focus = "wanted-line-#{first}-choice" if first
      end

      def drawn?(ref) = @lines.any? { it.ref == ref }

      def changed_reason(line, order)
        return t("market.wanted_choices.new.served_none_left") if order.nil?
        return t("market.sales.order.better", amount: helpers.picoins_label(order.price)) if still_drawable?(line)

        Game::Market::ApplyWantedChoices.failure_message(:best_order_changed)
      end

      # The posted order still stands but another now comes first.
      def still_drawable?(line)
        id = posted_ids[line.ref]
        id.present? && line.orders.any? && Game::Market::EligibleOrders.call(id, except: current_player.id).exists?(token: line.orders)
      end

      def flag_fields(refusals)
        rarities = @lines.to_h { [ it.ref, it.rarity ] }
        @field_refusals = {}
        refusals.each do |refusal|
          ref = posted_lines[refusal.line]&.ref
          next if refusal.code == :stamp_not_covered || !rarities.key?(ref)

          @field_refusals[[ ref, PRICE_FIELDS.fetch(refusal.code, :line) ]] ||= refusal_message(refusal, rarities[ref])
        end
        @dock_refusal = fields_dock_line(refusals)
        @focus = first_invalid_field
      end

      def refusal_message(refusal, rarity)
        values = refusal.code == :start_below_minimum ? { amount: helpers.picoins(refusal.amount), rarity: helpers.sale_rarity_name(rarity) } : {}
        Game::Market::ApplyWantedChoices.failure_message(refusal.code, **values)
      end

      def fields_dock_line(refusals)
        to_fix = @field_refusals.keys.count { |_, field| field != :line }
        short = refusals.find { it.code == :stamp_not_covered }
        [ (t("market.wanted_choices.new.to_fix", count: to_fix) if to_fix.positive?),
          (t("market.wanted_choices.new.stamps_short", amount: helpers.picoins(short.amount)) if short&.amount&.positive?),
          (Game::Market::ApplyWantedChoices.failure_message(:invalid_choices) if @field_refusals.keys.any? { |_, field| field == :line }) ].compact.join(" ")
          .presence || Game::Market::ApplyWantedChoices.failure_message(:invalid_choices)
      end

      def first_invalid_field
        @lines.each_with_index do |line, index|
          return "wanted-line-#{index}-start" if @field_refusals.key?([ line.ref, :start ])
          return "wanted-line-#{index}-duration" if @field_refusals.key?([ line.ref, :duration ])
        end
        nil
      end

      def answer(status:)
        respond_to do |format|
          format.turbo_stream { render :create, status: }
          format.html { render :new, status: }
        end
      end
  end
end
