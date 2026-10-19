module BackOffice
  # What the roadmap milestone and story pages share: the record a token
  # names (an unknown one is a 404), the fields of their one form, and a
  # refusal's message.
  module RoadmapEntries
    # The values the form shows: a record's, or those just sent back.
    Entry = Data.define(:wording_fr, :wording_en, :status, :shown)

    private
      def roadmap_milestone(token)
        Catalog::RoadmapMilestoneByToken.call(token) or raise ActiveRecord::RecordNotFound
      end

      def roadmap_story(token)
        Catalog::RoadmapStoryByToken.call(token) or raise ActiveRecord::RecordNotFound
      end

      def entry_of(record)
        Entry.new(wording_fr: record.wording_fr, wording_en: record.wording_en, status: record.status, shown: record.shown)
      end

      def entry_params
        { wording_fr: params[:wording_fr], wording_en: params[:wording_en], status: params[:status], shown: params[:shown] == "1" }
      end

      def sent_entry
        sent = entry_params
        Entry.new(**sent.slice(:wording_fr, :wording_en, :status).transform_values { it if it.is_a?(String) }, shown: sent[:shown])
      end

      def refusal_message(operation, code)
        operation.failure_message(code, limit: Catalog::RoadmapWording::LENGTH)
      end
  end
end
