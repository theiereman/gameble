module Accounts
  # A Steam persona name made fit to show (CAP-8): the label that titles a
  # player's public profile. Steam lets a name hold characters that show
  # nothing or reorder the text around them; they are dropped, so a name
  # cannot look blank, nor run a right-to-left override into the page:
  #
  # - control and format characters (\p{Cc}, \p{Cf}: NUL, the zero-width
  #   space U+200B, the bidi overrides and isolates U+202A to U+202E and
  #   U+2066 to U+2069), default-ignorable ones (the Hangul filler U+3164,
  #   variation selectors, the zero-width joiner U+200D) and the blank
  #   Braille pattern U+2800 are removed;
  # - every other space (\p{Zs}: the ideographic space U+3000, the no-break
  #   space U+00A0) becomes a plain one, and runs of spaces are squished;
  # - the name is cut to LENGTH graphemes, so a letter keeps its combining
  #   marks, an emoji its skin-tone modifier and a flag both its halves,
  #   then stripped.
  #
  # What remains must hold a letter, digit, symbol or punctuation mark, or
  # there is no name (nil). Dropping default-ignorables also drops the ZWJ
  # and variation selectors inside emoji sequences, which then show as
  # their parts. A string tagged with another encoding is read as UTF-8, its
  # invalid bytes dropped.
  #
  #   Accounts::PersonaName.clean("Ga\u200Bbe")   # => "Gabe"
  #   Accounts::PersonaName.clean("A\u3000B")     # => "A B"
  #   Accounts::PersonaName.clean("\u200B\u202E") # => nil
  #   Accounts::PersonaName.clean(42)             # => nil
  module PersonaName
    LENGTH = 64

    INVISIBLE = /[\p{Cc}\p{Cf}\p{Default_Ignorable_Code_Point}\u2800]/
    SPACE = /\p{Zs}/
    VISIBLE = /[\p{L}\p{N}\p{S}\p{P}]/

    def self.clean(value)
      return nil unless value.is_a?(String)

      name = value.dup.force_encoding(Encoding::UTF_8).scrub("")
      name = name.gsub(INVISIBLE, "").gsub(SPACE, " ").squish.each_grapheme_cluster.first(LENGTH).join.strip
      name if VISIBLE.match?(name)
    end
  end
end
