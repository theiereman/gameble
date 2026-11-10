module MarketRowsHelper
  SALE_TONES = { "open" => :accent, "sold" => :gold, "unsold" => :muted, "cancelled" => :muted, "withdrawn" => :muted }.freeze

  def sale_status_label(status)
    case status
    when "open" then t("market.rows.status.in_progress")
    when "sold" then t("market.rows.status.sold")
    when "unsold" then t("market.rows.status.no_bid")
    when "cancelled" then t("market.rows.status.cancelled")
    when "withdrawn" then t("market.rows.status.withdrawn")
    end
  end

  def sale_status_tone(status) = SALE_TONES.fetch(status)

  def sale_row_facts(row)
    [ [ t("market.rows.labels.price"), row_amount(row.current_price) ], [ t("market.rows.labels.end"), row_end(row.ends_at, row.ended_at) ] ]
  end

  def row_amount(amount) = render(PicoinAmountComponent.new(amount:, compact: true))

  def row_end(ends_at, ended_at)
    return local_time_tag(ended_at) if ended_at

    seconds = listing_seconds_left(ends_at)
    seconds.zero? ? t("market.rows.closing") : listing_time_left(seconds)
  end

  def sale_received_line(row) = tag.span(t("market.my_sales.received_html", amount: row_amount(row.received)), class: "market-row__received")

  def relist_sale_path(relist) = new_market_sale_path(ref: relist.ref, start: relist.start, buy_now: relist.buy_now, relisting: 1)

  def cancel_dialog_id(token) = "cancel-#{token}"

  def annonce_cancellable?(listing, viewer)
    viewer && listing.seller.id == viewer.id && listing.status == "open" && listing.leader.nil? && listing.ends_at > Time.current
  end
end
