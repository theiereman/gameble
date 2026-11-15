module Catalog
  module ThemeNaming
    def self.clean(name)
      name.is_a?(String) ? name.squish : nil
    end

    def self.valid?(name, length: Theme::NAME_LENGTH)
      !name.nil? && (1..length).cover?(name.length)
    end
  end
end
