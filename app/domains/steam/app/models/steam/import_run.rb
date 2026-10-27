module Steam
  class ImportRun < ApplicationRecord
    self.table_name = "steam_import_runs"

    STEPS = %w[app_list reviews tags details cards].freeze
    ERROR_LIMIT = 20
    MESSAGE_LIMIT = 500

    has_secure_token :token

    enum :status, { pending: "pending", running: "running", completed: "completed", failed: "failed", abandoned: "abandoned",
      ready: "ready", promoted: "promoted" },
      default: :pending, validate: true

    has_many :apps, class_name: "Steam::App", inverse_of: :import_run, dependent: nil

    scope :active, -> { where(status: %w[pending running]) }
    scope :latest_first, -> { order(created_at: :desc, id: :desc) }

    validates :step, inclusion: { in: STEPS }, allow_nil: true

    def self.stream_name(id)
      "Steam::ImportRun$#{id}"
    end

    def to_param
      token
    end

    def active?
      pending? || running?
    end

    def self.next_step(step)
      index = STEPS.index(step)
      index && STEPS[index + 1]
    end

    def self.cursor_for(step, last_appid: 0)
      { "step" => step, "last_appid" => last_appid }
    end

    def last_appid
      cursor.fetch("last_appid", 0).to_i
    end

    def reached?(step)
      current = STEPS.index(self.step)
      target = STEPS.index(step)
      current.present? && target.present? && current >= target
    end

    def apps_listed
      count_of("apps_listed")
    end

    def apps_reviewed
      count_of("apps_reviewed")
    end

    def apps_kept
      count_of("apps_kept")
    end

    def apps_excluded
      count_of("apps_excluded")
    end

    def tags_named
      count_of("tags_named")
    end

    def apps_detailed
      count_of("apps_detailed")
    end

    def apps_excluded_details
      count_of("apps_excluded_details")
    end

    def season_number
      count_of("season_number")
    end

    def cards_written
      count_of("cards_written")
    end

    def cards_refused
      count_of("cards_refused")
    end

    def count_of(name)
      counts.fetch(name, 0).to_i
    end

    Error = Data.define(:at, :message)

    def append_errors(messages, at: Time.current)
      stamp = at.utc.iso8601
      self.error_messages = (error_messages + messages.map { |message| { "at" => stamp, "message" => message.to_s.truncate(MESSAGE_LIMIT) } })
        .last(ERROR_LIMIT)
    end

    def latest_errors(limit = 5)
      error_messages.last(limit).reverse.map do |error|
        at = begin
          Time.iso8601(error["at"].to_s)
        rescue ArgumentError
          nil
        end
        Error.new(at: at, message: error["message"].to_s)
      end
    end
  end
end
