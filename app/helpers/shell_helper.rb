module ShellHelper
  PIXEL_DIRECTORY = Rails.root.join("app/frontend/images/pixel").freeze
  PIXEL_NAME = /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/

  PIXEL_CACHE = Concurrent::Map.new

  class UnknownPixelIcon < ArgumentError; end

  def pixel_icon(name, **attrs)
    trusted_svg = ShellHelper.pixel_source(name.to_s)
    attrs = attrs.merge(class: [ "pixel-icon", attrs[:class] ].compact.join(" "), aria: { hidden: true }, focusable: false)
    trusted_svg.sub("<svg ", "<svg #{tag.attributes(attrs)} ").html_safe
  end

  def self.pixel_source(name)
    raise UnknownPixelIcon, "unknown pixel icon: #{name.inspect}" unless name.match?(PIXEL_NAME)

    cache = Rails.env.development? ? {} : PIXEL_CACHE
    cache.fetch(name) do
      path = PIXEL_DIRECTORY.join("#{name}.svg")
      raise UnknownPixelIcon, "unknown pixel icon: #{name.inspect}" unless path.file?

      cache[name] = path.read.strip.freeze
    end
  end

  def shell_version
    ShellHelper.app_version
  end

  def self.app_version(env = ENV)
    env["GAMEBLE_VERSION"].presence || env["KAMAL_VERSION"].to_s.sub(/_uncommitted_.*\z/, "")[0, 7].presence || "dev"
  end

  def back_office_page?
    controller_path.start_with?("back_office/")
  end

  SCREEN_LABELS = {
    "library#show" => :sets,
    "library#cards" => :collection,
    "library#set" => :set,
    "cards" => :card,
    "boosters" => :booster,
    "packs" => :booster,
    "trades" => :trades,
    "friends" => :friends,
    "friend_profiles" => :profile,
    "public_profiles#set" => :set,
    "public_profiles" => :profile,
    "settings" => :profile,
    "sign_ins" => :sign_in,
    "feeds" => :feed,
    "achievements" => :achievements,
    "pages#legal" => :legal,
    "pages#how_it_works" => :how_it_works,
    "pages#more" => :more
  }.freeze

  def shell_home_label
    current_player ? t("shell.top_bar.home") : t("shell.top_bar.landing")
  end

  def shell_back_label
    current_player ? t("shell.top_bar.back") : t("shell.top_bar.back_landing")
  end

  def sign_in_button(label, origin:, class:, aria_label: nil)
    link_to label, sign_in_path(origin:), class:, aria: { label: aria_label }.compact
  end

  def shell_screen_label
    key = screen_label_key
    t("shell.screens.#{key}") if key
  end

  def shell_screen_labels
    key = screen_label_key
    I18n.available_locales.to_h { |locale| [ locale.to_s, t("shell.screens.#{key}", locale: locale) ] } if key
  end

  def screen_label_key
    back_office_page? ? :back_office : SCREEN_LABELS["#{controller_path}##{action_name}"] || SCREEN_LABELS[controller_path]
  end

  def shell_bank
    return @shell_bank if defined?(@shell_bank)

    @shell_bank = @bank || (current_player && Game::BankSummary.reserve(current_player))
  end

  def shell_trades_waiting
    return @shell_trades_waiting if defined?(@shell_trades_waiting)

    @shell_trades_waiting = current_player && Game::TradesWaiting.call(current_player)
  end

  def player_stream_tag
    return if current_player.nil? || back_office_page?

    turbo_stream_from(*PlayerStream.streamables(current_player), channel: PlayerStreamChannel)
  end

  def shell_tier_counts
    @shell_tier_counts ||= Game::TierCounts.call(current_player)
  end

  def shell_rarity_legend
    @shell_rarity_legend ||= Game::RarityLegend.call(current_player)
  end

  def shell_next_pack_in(bank)
    return if bank.nil? || bank[:reserve_full] || bank[:next_available_at].nil?

    [ (bank[:next_available_at] - Time.current).ceil, 0 ].max
  end

  DAY_SECONDS = 24 * 60 * 60

  def daily_bonus_seconds(bank)
    (bank[:next_bonus_at] - Time.current).ceil.clamp(0, DAY_SECONDS)
  end

  def format_clock(seconds)
    format("%02d:%02d:%02d", seconds / 3600, seconds % 3600 / 60, seconds % 60)
  end

  def format_remaining(seconds)
    seconds = [ seconds.to_i, 0 ].max
    hours, rest = seconds.divmod(3600)
    minutes, seconds = rest.divmod(60)
    hours.positive? ? format("%d:%02d:%02d", hours, minutes, seconds) : format("%02d:%02d", minutes, seconds)
  end

  def bank_changed_json(bank)
    { available: bank[:available], special: bank[:special], reserveFull: bank[:reserve_full], nextAvailableAt: bank[:next_available_at]&.utc&.iso8601,
      serverTime: Time.current.utc.iso8601 }.to_json
  end
end
