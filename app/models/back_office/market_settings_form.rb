module BackOffice
  # What the settings form draws and submits: the typed text of every field, read into a candidate row, beside the version its bounds come from.
  class MarketSettingsForm
    Rules = Game::Market::SettingsRules

    PERCENTS = %i[commission_basis_points increment_basis_points alert_destroyed_share_basis_points alert_top_share_basis_points].freeze
    DAYS = Rules::TARGETS
    SINGLE_GROUPS = {
      cap: %i[daily_cap],
      auctions: %i[duration_short_hours duration_medium_hours duration_long_hours preselected_duration_hours increment_basis_points
        soft_close_seconds unusual_maximum_multiple],
      commission: %i[commission_basis_points],
      averages: %i[average_sale_count average_window_days feed_threshold_multiple],
      alerts: %i[alert_destroyed_share_basis_points alert_picoins_per_player alert_top_share_basis_points]
    }.freeze
    MOMENTS = {
      cap: :now, auctions: :auction_creation, commission: :close, averages: :now, alerts: :now,
      entrustment: :now, stamp: :listing, minimum_price: :listing, income_days_target: :now
    }.freeze
    BLANKS = /[[:space:]]/
    WHOLE = /\A-?\d+\z/
    DECIMAL = /\A-?\d+([.,]\d+)?\z/

    attr_reader :settings, :token, :raw, :message_fr, :message_en
    attr_accessor :refusal

    def self.from_settings(settings) = new(settings:, token: settings.token)

    def self.from_params(params, settings:, token: settings&.token)
      params = params.to_h.symbolize_keys
      new(settings:, token:, raw: Rules::EDITABLE.index_with { params[it] }, message_fr: params[:message_fr], message_en: params[:message_en])
    end

    def initialize(settings:, token:, raw: {}, message_fr: nil, message_en: nil)
      @settings = settings
      @token = token
      @raw = raw
      @message_fr = message_fr
      @message_en = message_en
      @checked = false
    end

    # Shows the refusals beside the fields, for a save the rules turned down.
    def check
      @checked = true
      self
    end

    def candidate
      Rules::EDITABLE.index_with { |field| raw.key?(field) ? read(field, raw[field]) : settings&.public_send(field) }
    end

    def violations
      @violations ||= @checked && settings ? Rules.new(settings).violations(candidate) : {}
    end

    def violation(field) = violations[field]

    def violation_message(field)
      violation = violation(field) or return
      values = violation.values.transform_values { shown(field, it) }
      I18n.t("back_office.markets.settings.violations.#{violation.code}", **values)
    end

    def value_for(field)
      return raw[field].to_s if raw.key?(field)

      display_value(field, settings&.public_send(field))
    end

    def hint(field)
      parts = [ I18n.t("back_office.markets.settings.hints.currently", value: shown(field, settings.public_send(field)) || "-") ]
      parts << bounds_hint(field)
      parts << I18n.t("back_office.markets.settings.hints.optional") if Rules::OPTIONAL.include?(field)
      parts << I18n.t("back_office.markets.settings.moments.#{moment(field)}")
      parts.compact.join(" ")
    end

    def moment(field)
      row = field.to_s.sub(/_(#{Rules::RARITIES.join("|")})\z/, "").to_sym
      MOMENTS[row] || MOMENTS.find { |group, _| SINGLE_GROUPS[group]&.include?(field) }.last
    end

    def percent?(field) = PERCENTS.include?(field)

    def days?(field) = DAYS.include?(field)

    private

    def read(field, text)
      stripped = text.to_s.gsub(BLANKS, "")
      return nil if stripped.empty?

      if percent?(field) then percent_basis_points(stripped) || text
      elsif days?(field) then decimal(stripped)&.round(3) || text
      else stripped.match?(WHOLE) ? Integer(stripped, 10) : text
      end
    end

    def decimal(text) = text.match?(DECIMAL) ? BigDecimal(text.tr(",", ".")) : nil

    def percent_basis_points(text) = decimal(text)&.then { (it * 100).round }

    def bounds_hint(field)
      min, max = bounds(field)
      return unless min

      I18n.t("back_office.markets.settings.hints.bounds", min: shown(field, min), max: shown(field, max))
    end

    def bounds(field)
      if Rules::AMOUNTS.include?(field) then Rules.new(settings).amount_limits(field)
      elsif days?(field) then [ Rules::TARGET_RANGE.begin, Rules::TARGET_RANGE.end ]
      elsif Rules::RANGES.key?(field) then [ Rules::RANGES[field].begin, Rules::RANGES[field].end ]
      end
    end

    def shown(field, value)
      return display_value(field, value) if percent?(field) || days?(field)

      ActiveSupport::NumberHelper.number_to_delimited(value)
    end

    def display_value(field, value)
      return if value.nil?
      return plain_decimal(BigDecimal(value) / 100) if percent?(field)
      return plain_decimal(value) if days?(field)

      value.to_s
    end

    def plain_decimal(value) = value.to_s("F").sub(/\.0\z/, "")
  end
end
