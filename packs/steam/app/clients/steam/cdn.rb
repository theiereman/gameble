module Steam
  # Steam's image CDN (AD-17): images are served from there, never copied.
  # A GetItems store item gives an `asset_url_format` (a path holding
  # `${FILENAME}`) and the file names of its assets, the library capsule
  # among them, possibly hashed (`<hash>/library_capsule.jpg`).
  #
  #   Steam::Cdn.asset_url("steam/apps/620/${FILENAME}?t=1", "library_600x900.jpg")
  #   # => "https://shared.akamai.steamstatic.com/store_item_assets/steam/apps/620/library_600x900.jpg?t=1"
  module Cdn
    ASSET_BASE = "https://shared.akamai.steamstatic.com/store_item_assets/".freeze
    FILENAME = "${FILENAME}".freeze

    # The URL of `filename` from the item's format; nil when either is blank
    # or the format names no file.
    def self.asset_url(asset_url_format, filename)
      return if asset_url_format.blank? || filename.blank? || !asset_url_format.to_s.include?(FILENAME)

      ASSET_BASE + asset_url_format.to_s.sub(FILENAME) { filename.to_s }
    end
  end
end
