module Accounts
  # A production release's version, vMAJOR.MINOR.PATCH; a candidate (v1.3.0-rc.2), a sha or "dev" is none.
  class ReleaseVersion
    include Comparable

    FORMAT = /\Av(\d+)\.(\d+)\.(\d+)\z/

    attr_reader :parts

    def self.parse(name)
      match = FORMAT.match(name.to_s.strip)
      new(match.captures.map(&:to_i)) if match
    end

    def initialize(parts)
      @parts = parts
    end

    def <=>(other)
      parts <=> other.parts
    end

    def to_s
      "v#{parts.join(".")}"
    end
  end
end
