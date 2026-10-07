# The shell around every page (AD-28; DESIGN.md, Chrome): the pixel icons
# inlined in the HTML, whether the page belongs to the back-office, and the
# top bar's figures for the signed-in player, read once per request.
module ShellHelper
  PIXEL_DIRECTORY = Rails.root.join("app/frontend/images/pixel").freeze
  PIXEL_NAME = /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/

  # The exported files, read once per process (script/pixel_art/export.mjs
  # writes them; a change needs a restart outside development).
  PIXEL_CACHE = Concurrent::Map.new

  # Raised for a name that no exported icon carries.
  class UnknownPixelIcon < ArgumentError; end

  # An exported pixel icon (app/frontend/images/pixel/<name>.svg) inlined as
  # SVG, so `currentColor` follows the text. Decorative: hidden from
  # assistive technology and never focusable; its meaning is in the text or
  # accessible name beside it. Other attributes (class…) are added to the
  # <svg>; the class always includes "pixel-icon".
  #
  #   pixel_icon("arrow-left", class: "button__icon")
  def pixel_icon(name, **attrs)
    source = ShellHelper.pixel_source(name.to_s)
    attrs = attrs.merge(class: [ "pixel-icon", attrs[:class] ].compact.join(" "), aria: { hidden: true }, focusable: false)
    # Safe: our own exported file, and attributes escaped by tag.attributes.
    source.sub("<svg ", "<svg #{tag.attributes(attrs)} ").html_safe
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

  # The back-office gets the tokens and the top bar, without the atmosphere
  # or the tab bar (DESIGN.md, Back-office).
  def back_office_page?
    controller_path.start_with?("back_office/")
  end

  # The signed-in player's reserve (Game::BankSummary.reserve), for the
  # packs and reserve chips; nil for a visitor. Read once per request; the
  # page's own @bank (hub, booster screen, pack page) is reused.
  def shell_bank
    return @shell_bank if defined?(@shell_bank)

    @shell_bank = @bank || (current_player && Game::BankSummary.reserve(current_player))
  end

  # Copies held per rarity tier in the published season (Game::TierCounts),
  # for the rarity counter. Read once per request.
  def shell_tier_counts
    @shell_tier_counts ||= Game::TierCounts.call(current_player)
  end

  # Whole seconds to the next pack of the bank, rounded up; nil when the
  # reserve is full or nothing is scheduled.
  def shell_next_pack_in(bank)
    return if bank.nil? || bank[:reserve_full] || bank[:next_available_at].nil?

    [ (bank[:next_available_at] - Time.current).ceil, 0 ].max
  end

  # A UTC day, in seconds.
  DAY_SECONDS = 24 * 60 * 60

  # Whole seconds to the next daily bonus (00:00 UTC), rounded up, within a
  # day.
  def daily_bonus_seconds(bank)
    (bank[:next_bonus_at] - Time.current).ceil.clamp(0, DAY_SECONDS)
  end

  # "HH:MM:SS", the daily countdown's clock.
  def format_clock(seconds)
    format("%02d:%02d:%02d", seconds / 3600, seconds % 3600 / 60, seconds % 60)
  end

  # The detail of `gameble:bank-changed` for a bank (events.ts,
  # BankChangedDetail), as the claim's answer carries it to
  # bonus_arc_controller.ts.
  def bank_changed_json(bank)
    { available: bank[:available], reserveFull: bank[:reserve_full], nextAvailableAt: bank[:next_available_at]&.utc&.iso8601,
      serverTime: Time.current.utc.iso8601 }.to_json
  end
end
