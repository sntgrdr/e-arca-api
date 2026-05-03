module BatchArca
  class CreateService
    def initialize(user:, invoice_ids:, invoice_class:, idempotency_key: nil, parent_batch_id: nil)
      @user            = user
      @invoice_ids     = invoice_ids
      @invoice_class   = invoice_class
      @idempotency_key = idempotency_key
      @parent_batch_id = parent_batch_id
    end

    def call
      return too_many_error if @invoice_ids.size > BatchArcaProcess::MAX_INVOICES

      existing = find_existing_by_idempotency_key
      return { success: true, batch: existing } if existing

      invoices = load_and_validate_invoices
      return invoices if invoices.is_a?(Hash)

      create_batch(invoices)
    end

    private

    def find_existing_by_idempotency_key
      return nil if @idempotency_key.blank?

      BatchArcaProcess.find_by(user_id: @user.id, idempotency_key: @idempotency_key)
    end

    def load_and_validate_invoices
      unless BatchArcaProcess::ALLOWED_CLASSES.include?(@invoice_class)
        return { success: false, error: "Invalid invoice class" }
      end

      invoices = @invoice_class.constantize
                               .where(user_id: @user.id, id: @invoice_ids)
                               .to_a

      return { success: false, error: "No invoices provided" } if invoices.empty?

      if invoices.map(&:sell_point_id).uniq.size > 1
        return { success: false, error: "All invoices must belong to the same sell point" }
      end

      if invoices.map(&:invoice_type).uniq.size > 1
        return { success: false, error: "All invoices must have the same invoice type" }
      end

      invoices
    end

    def create_batch(invoices)
      batch = nil

      ActiveRecord::Base.transaction do
        batch = BatchArcaProcess.create!(
          user_id:         @user.id,
          sell_point_id:   invoices.first.sell_point_id,
          invoice_class:   @invoice_class,
          invoice_type:    invoices.first.invoice_type,
          status:          :pending,
          total_invoices:  invoices.size,
          idempotency_key: @idempotency_key,
          parent_batch_id: @parent_batch_id
        )

        invoices.each do |invoice|
          BatchArcaProcessInvoice.create!(
            batch_arca_process: batch,
            invoice:            invoice,
            arca_status:        :pending
          )
        end
      end

      BatchArcaProcessJob.perform_later(batch.id)
      { success: true, batch: batch }
    rescue ActiveRecord::RecordInvalid => e
      { success: false, error: e.message }
    end

    def too_many_error
      { success: false, error: "Batch cannot exceed #{BatchArcaProcess::MAX_INVOICES} invoices" }
    end
  end
end
