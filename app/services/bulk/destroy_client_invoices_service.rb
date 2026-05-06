module Bulk
  class DestroyClientInvoicesService < DestroyService
    private

    # Invoices with a CAE are AFIP-authorized and cannot be deleted.
    # Use discard! (soft delete via Discard gem) so the record is preserved
    # for audit/reporting but excluded from normal queries.
    def skip_reason(record)
      "has_cae" if record.cae.present?
    end

    def build_identifier(record)
      record.number.to_s
    end
  end
end
