require "digest"

module Catalog
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
