module Steam
  module Cdn
    ASSET_BASE = "https://shared.akamai.steamstatic.com/store_item_assets/".freeze
    FILENAME = "${FILENAME}".freeze

    IMAGE_SOURCES = %w[https://*.steamstatic.com].freeze

    # Steam gives an `asset_url_format` holding ${FILENAME}; an asset's file name may be hashed (`<hash>/library_capsule.jpg`).
    def self.asset_url(asset_url_format, filename)
      return if asset_url_format.blank? || filename.blank? || !asset_url_format.to_s.include?(FILENAME)

      ASSET_BASE + asset_url_format.to_s.sub(FILENAME) { filename.to_s }
    end
  end
end
