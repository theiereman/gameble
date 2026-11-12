module MarketBidsHelper
  ANNONCE_ACTIONS = {
    "annonce-field" => { typed: :typed, entered: :entered, retermed: :retermed },
    "annonce-foot" => { raise: :raise },
    "annonce-dialog" => { confirmed: :confirmed },
    "annonce-status" => {},
    "listing-clock" => { ended: :ended }
  }.freeze
  ANNONCE_DOCUMENT_ACTIONS = "turbo:morph@document->annonce#morphed".freeze
  ANSWER_KINDS = { new_leader: :leading, raise: :raised }.freeze

  def annonce_root_data
    actions = "#{screen_actions("annonce", ANNONCE_ACTIONS)} #{ANNONCE_DOCUMENT_ACTIONS}"
    { controller: "annonce live-refresh", live_refresh_signal_value: "listing-updated", action: actions, annonce_locale_value: I18n.locale,
      annonce_strings_value: screen_strings("market.bids.strings") }.merge(screen_outlets("annonce", ANNONCE_ACTIONS.keys - %w[listing-clock]))
  end

  def annonce_status_data(listing, viewer, events)
    { status_text: annonce_status_text(listing, viewer), status_ends_at: listing.ends_at.utc.iso8601, status_bidder: events.bidder }
  end

  def annonce_status_text(listing, viewer)
    figures = { amount: picoins_label(listing.current_price), time: local_time_text(listing.ends_at, :time) }
    return t("market.listings.status.no_leader", **figures) unless listing.leader
    return t("market.listings.status.leading_you", **figures) if viewer && listing.leader.id == viewer.id

    t("market.listings.status.leading", **figures, name: CGI.unescapeHTML(strip_tags(render(PlayerNameComponent.new(player: listing.leader, viewer: nil, linked: false)))))
  end

  def bid_field_data(sheet, answered:)
    { controller: "annonce-field", annonce_field_minimum_value: sheet.minimum, annonce_field_available_value: sheet.available,
      annonce_field_buy_now_value: sheet.buy_now_price.to_i, annonce_field_own_maximum_value: sheet.own_maximum.to_i,
      annonce_field_price_value: sheet.current_price, annonce_field_unusual_multiple_value: sheet.unusual_multiple, annonce_field_answered_value: answered }
  end

  SHORTCUT_RAISES = [ 10, 25 ].freeze

  def bid_shortcuts(sheet)
    return [] if sheet.leading

    raises = SHORTCUT_RAISES.map { |percent| [ percent, (sheet.minimum * (100 + percent)).ceildiv(100 * 100) * 100 ] }
    raises = raises.select { |_, amount| sheet.buy_now_price.nil? || amount < sheet.buy_now_price }
    [ [ t("market.bids.form.shortcuts.minimum", amount: picoins(sheet.minimum)), sheet.minimum ],
      *raises.map { |percent, amount| [ t("market.bids.form.shortcuts.raise", percent:, amount: picoins(amount)), amount ] } ]
  end

  def bid_minimum_text(sheet)
    if sheet.leading
      t("market.bids.form.minimum_raise_html", amount: bid_amount(sheet.own_maximum))
    else
      t("market.bids.form.minimum_html", amount: bid_amount(sheet.minimum))
    end
  end

  def bid_refusal_text(code, sheet:, drawn_minimum:)
    case code
    when :below_minimum then bid_below_minimum_text(sheet, drawn_minimum)
    when :more_than_available then t("errors.game.more_than_available", amount: picoins(sheet&.available.to_i))
    when :invalid_price then t("errors.game.invalid_price")
    when :own_listing then t("errors.game.own_listing")
    when :market_closed then t("errors.game.market_closed")
    when :market_busy then t("errors.game.market_busy")
    when :auction_ended then t("errors.game.auction_ended")
    when :listing_withdrawn then t("errors.game.listing_withdrawn")
    when :throttled then t("market.bids.refusals.throttled")
    else t("errors.game.listing_not_found")
    end
  end

  def bid_answer_kind(answer) = ANSWER_KINDS.fetch(answer.branch) { answer.equal_maximum ? :equal : :beaten }

  def bid_answer_title(kind)
    case kind
    when :leading then t("market.bids.answers.leading.title")
    when :raised then t("market.bids.answers.raised.title")
    when :equal then t("market.bids.answers.equal.title")
    when :beaten then t("market.bids.answers.beaten.title")
    end
  end

  def bid_answer_body(kind, answer, posted_amount)
    figures = { price: bid_amount(answer.price), maximum: bid_amount(answer.maximum), minimum: bid_amount(answer.minimum), offer: bid_amount(posted_amount) }
    case kind
    when :leading then t("market.bids.answers.leading.body_html", **figures)
    when :raised then t("market.bids.answers.raised.body_html", **figures)
    when :equal then t("market.bids.answers.equal.body_html", **figures)
    when :beaten then t("market.bids.answers.beaten.body_html", **figures)
    end
  end

  def bid_dialog_amount = tag.span(data: { annonce_dialog_target: "amount" })

  def bid_dialog_multiple = tag.span(data: { annonce_dialog_target: "multiple" })

  def bid_card_name(card) = "#{card.title}, #{CardStrings.new.rarity_name(card.rarity).downcase}"

  def bid_amount(amount) = amount && render(PicoinAmountComponent.new(amount:))

  private
    def bid_below_minimum_text(sheet, drawn_minimum)
      amount = picoins(sheet&.minimum.to_i)
      return t("errors.game.below_minimum", amount:) if sheet.nil? || sheet.minimum.to_s == drawn_minimum

      t("market.bids.refusals.price_moved", amount:)
    end
end
