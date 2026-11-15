module Game
  # A name as a player typed it, with invisible and control characters dropped and every space a plain one;
  # empty when nothing visible is left.
  module VisibleName
    def self.call(name)
      return "" unless name.is_a?(String)

      name = name.dup.force_encoding(Encoding::UTF_8).scrub("").unicode_normalize(:nfc)
      name = name.gsub(Accounts::PersonaName::INVISIBLE, "").gsub(Accounts::PersonaName::SPACE, " ").squish
      Accounts::PersonaName::VISIBLE.match?(name) ? name : ""
    end
  end
end
