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

  # The signed-in player's bank (Game::BankSummary), for the packs chip; nil
  # for a visitor. Read once per request; the hub's own @bank is reused.
  def shell_bank
    return @shell_bank if defined?(@shell_bank)

    @shell_bank = @bank || (current_player && Game::BankSummary.call(current_player))
  end

  # Copies held per rarity tier in the published season (Game::TierCounts),
  # for the rarity counter. Read once per request.
  def shell_tier_counts
    @shell_tier_counts ||= Game::TierCounts.call(current_player)
  end

  # Whole seconds to the next pack of the bank, rounded up; nil when the
  # reserve is full or nothing is scheduled.
  def shell_next_pack_in(bank)
    return if bank.nil? || shell_reserve_full?(bank) || bank[:next_available_at].nil?

    [ (bank[:next_available_at] - Time.current).ceil, 0 ].max
  end

  # The reserve holds Game::Pack::BANK_SIZE boosters (EXPERIENCE.md, Reserve
  # full): the countdown gives way to "Réserve pleine".
  def shell_reserve_full?(bank)
    bank[:available] >= Game::Pack::BANK_SIZE
  end
end
