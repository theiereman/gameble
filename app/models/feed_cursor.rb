class FeedCursor
  PURPOSE = "feed cursor".freeze

  def self.encode(position)
    occurred_at, id = position
    encryptor.encrypt_and_sign([ occurred_at.utc.iso8601(6), id ], purpose: PURPOSE)
  end

  def self.decode(token)
    return if token.blank?

    occurred_at, id = encryptor.decrypt_and_verify(token.to_s, purpose: PURPOSE)
    [ Time.iso8601(occurred_at), Integer(id) ]
  rescue ActiveSupport::MessageEncryptor::InvalidMessage, ArgumentError, TypeError
    nil
  end

  def self.encryptor
    ActiveSupport::MessageEncryptor.new(Rails.application.key_generator.generate_key(PURPOSE, 32), serializer: JSON)
  end
  private_class_method :encryptor
end
