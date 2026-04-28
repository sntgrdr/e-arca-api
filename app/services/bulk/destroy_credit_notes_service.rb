module Bulk
  class DestroyCreditNotesService < DestroyService
    private

    # Credit notes with a CAE are AFIP-authorized and cannot be deleted.
    def skip_reason(record)
      "has_cae" if record.cae.present?
    end

    def build_identifier(record)
      record.number.to_s
    end
  end
end
