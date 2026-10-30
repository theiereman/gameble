module Catalog
  module ShareImageByToken
    def self.call(token)
      return unless token.is_a?(String) && token.present?

      image = ShareImage.find_by(token:)&.image
      image.download if image&.attached?
    rescue ActiveStorage::FileNotFoundError
      nil
    end
  end
end
