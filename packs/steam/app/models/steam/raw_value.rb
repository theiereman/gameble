module Steam
  # Reads a value of a Steam answer defensively (story 2.11): Steam's JSON is
  # parsed as it comes, so any field may hold another type, an out-of-range
  # number or a NUL byte. Each reader returns a valid value or a neutral one
  # (nil, {}), never raises, so one malformed app is excluded with a reason
  # and its page goes on.
  #
  #   Steam::RawValue.integer("812", min: 0, max: Steam::RawValue::INT4_MAX) # => 812
  #   Steam::RawValue.integer(1.5, min: 0, max: 10)                          # => nil
  #   Steam::RawValue.string("Portal\u0000 2")                               # => "Portal 2"
  #   Steam::RawValue.object([ 1 ])                                          # => {}
  module RawValue
    # The bounds of the columns and of Ruby's Time: an int4 column
    # (review_count, tag_ids; a Steam appid is a positive one), a bigint
    # column (price_change_number), a Unix timestamp up to the end of year
    # 9999.
    INT4_MAX = 2**31 - 1
    INT8_MAX = 2**63 - 1
    TIMESTAMP_MAX = 253_402_300_799
    NUL = "\u0000".freeze
    DIGITS = /\A\d+\z/

    # An Integer, or a String of digits, within min..max; anything else
    # (a Float, a negative string, another type) is nil.
    def self.integer(value, min:, max:)
      number = case value
      when Integer then value
      when String then value.to_i if DIGITS.match?(value)
      end
      number if number&.between?(min, max)
    end

    # A String without its NUL bytes; anything else is nil.
    def self.string(value)
      value.delete(NUL) if value.is_a?(String)
    end

    # A JSON object: a Hash, or {} for anything else.
    def self.object(value)
      value.is_a?(Hash) ? value : {}
    end

    # `value` with the NUL bytes removed from every string, keys included,
    # however deep: Postgres refuses "\u0000" in a jsonb column.
    def self.scrub(value)
      case value
      when String then value.delete(NUL)
      when Hash then value.to_h { |key, item| [ scrub(key), scrub(item) ] }
      when Array then value.map { |item| scrub(item) }
      else value
      end
    end
  end
end
