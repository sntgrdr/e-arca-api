module Bulk
  class DestroyClientsService < DestroyService
    private

    def skip_reason(record)
      return "final_client" if record[:final_client]
      "has_invoices" if Invoice.where(client_id: record.id).exists?
    end

    def build_identifier(record)
      "#{record.legal_name} — #{record.legal_number}"
    end
  end
end
