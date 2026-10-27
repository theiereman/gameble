module Catalog
  module ThemeNaming
    def self.clean(name)
      name.is_a?(String) ? name.squish : nil
    end

    def self.valid?(name)
      !name.nil? && (1..Theme::NAME_LENGTH).cover?(name.length)
    end
  end
end
