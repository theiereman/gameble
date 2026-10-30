module Catalog
  class ShareImage < ApplicationRecord
    self.table_name = "catalog_share_images"

    LOCALES = CardText::LOCALES
    FINGERPRINT = /\A\h{64}\z/

    has_secure_token :token, length: 24

    belongs_to :card_season, class_name: "Catalog::CardSeason"

    has_one_attached :image

    attr_readonly :card_season_id, :locale

    validates :locale, inclusion: { in: LOCALES }
    validates :fingerprint, format: { with: FINGERPRINT }

    def self.stream_name(id)
      "Catalog::ShareImage$#{id}"
    end

    def self.file_stored?(key:, service_name:)
      ActiveStorage::Blob.services.fetch(service_name) { return false }.exist?(key)
    end

    def file_stored?
      image.attached? && self.class.file_stored?(key: image.blob.key, service_name: image.blob.service_name)
    end

    def to_param
      token
    end
  end
end
