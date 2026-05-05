module BatchArca
  class RetryService
    def initialize(batch:)
      @batch = batch
    end

    def call
      ActiveRecord::Base.transaction do
        @batch.batch_arca_process_invoices
              .where(arca_status: %w[failed blocked])
              .update_all(arca_status: "pending", arca_error: nil, processed_at: nil)

        authorized_count = @batch.batch_arca_process_invoices.where(arca_status: "authorized").count

        @batch.update!(
          status:            :pending,
          failed_invoices:   0,
          processed_invoices: authorized_count,
          error_message:     nil
        )
      end

      BatchArcaProcessJob.perform_later(@batch.id)
      { success: true, batch: @batch }
    rescue ActiveRecord::RecordInvalid => e
      { success: false, error: e.message }
    end
  end
end
