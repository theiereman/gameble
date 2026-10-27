module Accounts
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
