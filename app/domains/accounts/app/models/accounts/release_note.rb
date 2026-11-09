module Accounts
  class ReleaseNote < ApplicationRecord
    self.table_name = "accounts_release_notes"

    TITLE_LENGTH = 80
    BODY_LENGTH = 1500
    TEXTS = %i[title_fr title_en body_fr body_en].freeze

    has_secure_token :token, length: 24

    has_many :reads, class_name: "Accounts::ReleaseNoteRead", inverse_of: :release_note, dependent: nil

    enum :state, { draft: "draft", ready: "ready", skipped: "skipped" }, validate: true

    def self.stream_name
      "Accounts::ReleaseNotes"
    end

    def self.clean(texts)
      {
        title_fr: texts[:title_fr].to_s.squish, title_en: texts[:title_en].to_s.squish,
        body_fr: clean_body(texts[:body_fr]), body_en: clean_body(texts[:body_en])
      }
    end

    def self.clean_body(body)
      body.to_s.gsub("\r\n", "\n").lines.map(&:rstrip).join("\n").gsub(/\n{3,}/, "\n\n").strip
    end

    def self.fitting?(texts)
      texts[:title_fr].length <= TITLE_LENGTH && texts[:title_en].length <= TITLE_LENGTH &&
        texts[:body_fr].length <= BODY_LENGTH && texts[:body_en].length <= BODY_LENGTH
    end

    def self.complete?(texts)
      TEXTS.all? { texts[it].present? }
    end

    def to_param
      token
    end

    def release_version
      ReleaseVersion.parse(version)
    end

    def texts
      TEXTS.index_with { self[it] }
    end

    def complete?
      self.class.complete?(texts)
    end

    def title(locale = I18n.locale)
      locale.to_s == "fr" ? title_fr : title_en
    end

    def body(locale = I18n.locale)
      locale.to_s == "fr" ? body_fr : body_en
    end
  end
end
