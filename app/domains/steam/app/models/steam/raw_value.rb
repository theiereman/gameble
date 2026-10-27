module Steam
  module RawValue
    INT4_MAX = 2**31 - 1
    INT8_MAX = 2**63 - 1
    TIMESTAMP_MAX = 253_402_300_799
    NUL = "\u0000".freeze
    DIGITS = /\A\d+\z/

    def self.integer(value, min:, max:)
      number = case value
      when Integer then value
      when String then value.to_i if DIGITS.match?(value)
      end
      number if number&.between?(min, max)
    end

    def self.string(value)
      clean(value) if value.is_a?(String)
    end

    def self.object(value)
      value.is_a?(Hash) ? value : {}
    end

    # Postgres refuses NUL bytes and invalid UTF-8 in a jsonb column.
    def self.scrub(value)
      case value
      when String then clean(value)
      when Hash then value.to_h { |key, item| [ scrub(key), scrub(item) ] }
      when Array then value.map { |item| scrub(item) }
      else value
      end
    end

    def self.clean(string)
      string.scrub("").delete(NUL)
    end
    private_class_method :clean
  end
end
