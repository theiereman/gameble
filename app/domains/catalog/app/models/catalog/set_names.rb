require "digest"

module Catalog
  # The names franchise and studio sets are built from. Pure functions.
  #
  # A franchise's name drops ™ ® © and a trailing " Franchise", " Series" or
  # " - Official". A company's name (a developer, a publisher) drops ™ ® ©, a
  # platform in brackets ("(Mac)", "(Mac/Linux)") and its trailing legal
  # suffixes; its company form is that name without case. A name's form is
  # its words; its merge form, those words joined without separators, is
  # shared by names differing only by case or punctuation ("Watch_Dogs",
  # "WatchDogs"). A set's key is a form parameterized, or "x-" and a digest
  # of the form when some character of it has no Latin transliteration.
  #
  #   Catalog::SetNames.franchise("Tom Clancy Franchise")          # => "Tom Clancy"
  #   Catalog::SetNames.company("CAPCOM Co., Ltd.")                # => "CAPCOM"
  #   Catalog::SetNames.company_form("Feral Interactive (Mac)")    # => "feral interactive"
  #   Catalog::SetNames.form("S.T.A.L.K.E.R.")                     # => "s t a l k e r"
  #   Catalog::SetNames.merge_form("S.T.A.L.K.E.R.")               # => "stalker"
  #   Catalog::SetNames.key("final fantasy")                       # => "final-fantasy"
  #   Catalog::SetNames.title_matches?("Watch_Dogs 2", "WatchDogs") # => true
  #
  # A title matches a franchise name when they share a whole word that is no
  # stopword and is at least three letters long or the name's only word, or
  # when the name's words, joined, are a run of the title's words joined.
  # Words are lowercase letters and digits, apostrophes removed first.
  module SetNames
    MARKS = /[™®©]/
    FRANCHISE_SUFFIX = /\s+(?:franchise|series|-\s*official)\z/i
    PLATFORM_NAME = /(?:mac os x|macos|mac|os x|linux|steamos|windows|pc)/i
    PLATFORM = /\s*\(\s*#{PLATFORM_NAME}(?:\s*(?:[\/,&]|\band\b)\s*#{PLATFORM_NAME})*\s*\)/i
    LEGAL_SUFFIX = /[\s,]+(?:co|ltd|inc|llc|gmbh|s\.?\s?a|s\.?\s?r\.?\s?l|k\.?\s?k|corp|corporation|limited)\.?\z/i
    TRAILING_SEPARATORS = /[\s,]+\z/
    STOPWORDS = %w[the of and a an in on game games simulator].to_set.freeze
    MIN_WORD_LENGTH = 3
    EXEMPT_FROM_TITLES = [ "science adventure", "world of darkness" ].to_set.freeze
    DIGEST_LENGTH = 12
    # What I18n.transliterate puts in place of a character it cannot transliterate.
    UNTRANSLITERATED = "?".freeze

    def self.franchise(name)
      name.gsub(MARKS, "").squish.sub(FRANCHISE_SUFFIX, "").squish
    end

    def self.form(name)
      words(name).join(" ")
    end

    def self.merge_form(name)
      words(name).join
    end

    def self.company(name)
      without_legal_suffixes(name.gsub(MARKS, "").gsub(PLATFORM, "").squish)
    end

    def self.company_form(name)
      company(name).downcase
    end

    def self.key(form)
      readable = form.parameterize
      return readable if readable.present? && !I18n.transliterate(form).include?(UNTRANSLITERATED)

      "x-#{Digest::SHA256.hexdigest(form)[0, DIGEST_LENGTH]}"
    end

    def self.exempt_from_titles?(name)
      EXEMPT_FROM_TITLES.include?(form(name))
    end

    def self.title_matches?(title, name)
      return false if title.nil?

      title_words = words(title)
      name_words = words(name)
      shares_word?(title_words, name_words) || holds_run?(title_words, name_words.join)
    end

    def self.words(text)
      text.downcase.delete("'’").scan(/[[:alnum:]]+/)
    end

    def self.without_legal_suffixes(name)
      loop do
        shorter = name.sub(TRAILING_SEPARATORS, "").sub(LEGAL_SUFFIX, "")
        return shorter if shorter == name

        name = shorter
      end
    end

    def self.shares_word?(title_words, name_words)
      name_words.any? do |word|
        !STOPWORDS.include?(word) && (word.length >= MIN_WORD_LENGTH || name_words.one?) && title_words.include?(word)
      end
    end

    def self.holds_run?(title_words, joined)
      return false if joined.empty?

      title_words.each_index.any? do |first|
        (first...title_words.size).any? { |last| title_words[first..last].join == joined }
      end
    end

    private_class_method :words, :without_legal_suffixes, :shares_word?, :holds_run?
  end
end
