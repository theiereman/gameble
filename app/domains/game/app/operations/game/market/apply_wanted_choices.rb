module Game
  module Market
    # The wanted table in one validation: each line's copies sold to the orders the table drew, put up at auction or entrusted,
    # all or nothing, in one ledger post so the stamps net against the same validation's proceeds.
    class ApplyWantedChoices < Operation
      include OrderServing
      include ListingOpening
      include Entrusting

      CHOICES = %w[order auction entrust].freeze

      Line = Data.define(:index, :card_season_id, :copies, :choice, :order_tokens, :starting_price, :duration_hours) do
        def auction? = choice == "auction"

        def entrusted_copies = auction? ? 0 : copies - order_tokens.size
      end

      Applied = Data.define(:sold, :listed, :entrusted, :skipped)
      Sold = Data.define(:line, :order, :received)
      Listed = Data.define(:line, :listing)
      Entrusted = Data.define(:line, :copies, :minted)
      Skipped = Data.define(:line, :copies)
      Refused = Data.define(:line, :code, :amount) do
        def initialize(line:, code:, amount: nil) = super
      end
      Changed = Data.define(:line, :order)

      def call(player:, lines:, settings_token:)
        player = step require_player(player)
        lines = step parse(lines)
        now = Time.current
        drawn = Order.where(token: lines.flat_map(&:order_tokens)).to_a
        owners = drawn.map(&:player_id)

        transaction do
          TradeLocks.players(player.id, *owners)
          step lock_bank(player)
          settings = step current_settings(settings_token.to_s)
          holdings = lock_holdings([ player.id, *owners ], lines.map(&:card_season_id))
          orders = Order.lock.where(id: drawn.map(&:id)).order(:id).index_by(&:token)
          sales = step still_drawn(lines, orders, player, now)
          rarities = rarities_of(lines)
          values = rarities.transform_values { settings.entrustment(it) }
          entrusted, skipped = split_entrusted(lines, rarities, values, CapLeft.call(player.id, settings:, now:))
          funds = Balance.call(player).available + sales.sum { |_, order| received(order, settings) } + entrusted.sum(&:minted)
          step fields_valid(lines, holdings.fetch(player.id), rarities, settings, funds)
          step(Failure(:nothing_fits)) if sales.empty? && entrusted.empty? && lines.none?(&:auction?)

          applied = apply(player, lines, sales, entrusted, skipped, holdings:, rarities:, values:, settings:, now:)
          step publish(applied_event(player, lines, applied), stream_name: stream_name(player.id))
          applied
        end
      rescue ActiveRecord::Deadlocked
        step Failure(:market_busy)
      end

      private

      def parse(lines)
        lines = lines.to_a
        return Failure(:empty_batch) if lines.empty?

        parsed = lines.each_with_index.map { |raw, index| line_of(raw, index) }
        malformed = parsed.each_index.reject { parsed[it] }.map { Refused.new(line: it, code: :invalid_choice) }
        malformed.empty? ? Success(parsed) : Failure([ :invalid_choices, malformed ])
      end

      def line_of(raw, index)
        return unless raw.is_a?(Hash)

        raw = raw.symbolize_keys
        card_season_id = Integer(raw[:card_season_id], exception: false)
        copies = Integer(raw[:copies], exception: false)
        choice = raw[:choice].to_s
        tokens = choice == "order" ? raw[:order_tokens] || [] : []
        return unless card_season_id&.positive? && copies&.positive? && CHOICES.include?(choice) && tokens.is_a?(Array) && tokens.size <= copies

        Line.new(index:, card_season_id:, copies:, choice:, order_tokens: tokens.map(&:to_s), starting_price: raw[:starting_price],
          duration_hours: raw[:duration_hours])
      end

      def current_settings(settings_token)
        settings = CurrentSettings.call
        return Failure(:market_closed) unless settings&.open
        return Failure(:amounts_changed) unless settings.token == settings_token

        Success(settings)
      end

      def lock_holdings(player_ids, card_season_ids)
        player_ids.uniq.sort.to_h { |player_id| [ player_id, TradeLocks.holdings(player_id, card_season_ids.uniq) ] }
      end

      def still_drawn(lines, orders, player, now)
        draws = EligibleOrders.draw(lines.map { [ it.card_season_id, it.order_tokens.size ] }, except: player.id, now:)
        sales = []
        changed = lines.zip(draws).filter_map do |line, best_orders|
          first_changed = nil
          line.order_tokens.each_with_index do |token, position|
            best = best_orders[position]
            drawn = orders[token]
            if drawn && drawn.id == best&.id
              sales << [ line, drawn ]
            else
              first_changed ||= Changed.new(line: line.index, order: best)
            end
          end
          first_changed
        end
        changed.empty? ? Success(sales) : Failure([ :best_order_changed, changed ])
      end

      def rarities_of(lines)
        Catalog::CardSeason.where(id: lines.map(&:card_season_id)).where.not(rarity: nil).pluck(:id, :rarity).to_h.transform_values(&:to_sym)
      end

      def received(order, settings) = order.price - AuctionMath.commission(order.price, settings.commission_basis_points)

      def split_entrusted(lines, rarities, values, cap_left)
        entrusting = lines.select { it.entrusted_copies.positive? && rarities.key?(it.card_season_id) }
        fits = copies_within_cap(entrusting.map { [ it.card_season_id, it.entrusted_copies ] }, values, cap_left)
        entrusted = entrusting.zip(fits).select { |_, copies| copies.positive? }
          .map { |line, copies| Entrusted.new(line: line.index, copies:, minted: copies * values.fetch(line.card_season_id)) }
        skipped = entrusting.zip(fits).select { |line, copies| copies < line.entrusted_copies }
          .map { |line, copies| Skipped.new(line: line.index, copies: line.entrusted_copies - copies) }
        [ entrusted, skipped ]
      end

      def fields_valid(lines, own, rarities, settings, funds)
        short = lines.group_by(&:card_season_id).select { |card_season_id, same| same.sum(&:copies) > free_copies(own[card_season_id]) }
        stamps = 0
        stamps_short = lines.select(&:auction?).sum { stamps_of(it, rarities[it.card_season_id], settings) } - funds
        refused = lines.flat_map do |line|
          rarity = rarities[line.card_season_id]
          codes = [ (:not_enough_copies if short.key?(line.card_season_id)), (:no_rarity unless rarity) ]
          if line.auction?
            codes.concat(listing_codes(line, rarity, settings))
            stamps += stamps_of(line, rarity, settings)
            codes << :stamp_not_covered if stamps > funds
          end
          codes.compact.map { Refused.new(line: line.index, code: it, amount: refusal_amount(it, rarity, settings, stamps_short)) }
        end
        refused.empty? ? Success() : Failure([ :invalid_choices, refused ])
      end

      def stamps_of(line, rarity, settings) = rarity ? settings.stamp(rarity) * line.copies : 0

      def refusal_amount(code, rarity, settings, stamps_short)
        case code
        when :start_below_minimum then settings.minimum_price(rarity)
        when :stamp_not_covered then stamps_short
        end
      end

      def free_copies(holding) = holding ? holding.quantity - holding.reserved : 0

      def listing_codes(line, rarity, settings)
        price = amount(line.starting_price)
        [ price, (price_rule(settings, rarity, price.value!) if price.success? && rarity), duration_rule(settings, line.duration_hours) ].compact.filter_map(&:failure)
      end

      def apply(player, lines, sales, entrusted, skipped, holdings:, rarities:, values:, settings:, now:)
        sales.each { |line, order| move_order_copy(order:, seller_id: player.id, card_season_id: line.card_season_id, holdings:, now:) }
        opened = lines.select(&:auction?).flat_map do |line|
          holding = holdings.fetch(player.id).fetch(line.card_season_id)
          Array.new(line.copies) { [ line, *open_listing(player, holding, settings, rarities.fetch(line.card_season_id), amount(line.starting_price).value!, line.duration_hours) ] }
        end
        quantities = entrusted_quantities(lines, entrusted)
        mint = entrust(player.id, quantities, holdings.fetch(player.id), values, settings, now:) if quantities.any?
        settled = sales.each_with_index.sort_by { |(line, _), position| [ line.card_season_id, position ] }.flat_map do |(line, order), _|
          settle_order(order:, seller_id: player.id, card_season_id: line.card_season_id, commission_settings: settings, now:)
        end
        Ledger.post([ *settled, *opened.map(&:third), *mint ])
        Applied.new(sold: sales.map { |line, order| Sold.new(line: line.index, order:, received: received(order, settings)) },
          listed: opened.map { |line, listing, _| Listed.new(line: line.index, listing:) }, entrusted:, skipped:)
      end

      def entrusted_quantities(lines, entrusted)
        entrusted.each_with_object(Hash.new(0)) { |row, quantities| quantities[lines.fetch(row.line).card_season_id] += row.copies }
      end

      def applied_event(player, lines, applied)
        WantedChoicesApplied.with(seller_id: player.id,
          sales: applied.sold.map { { order_id: it.order.id, buyer_id: it.order.player_id, card_season_id: lines.fetch(it.line).card_season_id, price: it.order.price } },
          listing_ids: applied.listed.map { it.listing.id },
          entrusted: entrusted_quantities(lines, applied.entrusted).map { |card_season_id, quantity| { card_season_id:, quantity: } })
      end
    end
  end
end
