module BatchArca
  class ProcessorService
    def initialize(batch)
      @batch = batch
    end

    def call
      @batch.update!(status: :processing)

      join_records = @batch.batch_arca_process_invoices
                           .includes(:invoice)
                           .joins(:invoice)
                           .order(Arel.sql("CAST(invoices.number AS INTEGER) ASC"))

      join_records.each do |join|
        next if join.authorized? # already reconciled in a previous attempt

        process_one(join)
        break if @batch.reload.failed?
      end

      @batch.update!(status: :completed) unless @batch.reload.failed?
    rescue StandardError => e
      Rails.logger.error("[BatchArca::ProcessorService] batch_id=#{@batch.id} FATAL: #{e.class}: #{e.message}")
      @batch.update!(status: :failed, error_message: e.message)
    end

    private

    def process_one(join)
      join.update!(arca_status: :processing)

      result = send_service(join.invoice).call

      if result[:success]
        mark_authorized(join)
      else
        reconcile_or_fail(join, result[:errors])
      end
    rescue Faraday::TimeoutError, Faraday::ConnectionFailed => e
      Rails.logger.warn("[BatchArca] network error for invoice #{join.invoice.id}, attempting reconciliation")
      reconcile_or_fail(join, e.message)
    end

    def reconcile_or_fail(join, error_msg)
      result = Invoices::ReconcileWithArcaService.new(invoice: join.invoice).call

      if result[:authorized]
        mark_authorized(join)
      else
        mark_failed(join, error_msg)
        block_remaining(join)
      end
    end

    def mark_authorized(join)
      join.update!(arca_status: :authorized, processed_at: Time.zone.now)
      @batch.increment!(:processed_invoices)
    end

    def mark_failed(join, error_msg)
      join.update!(arca_status: :failed, arca_error: error_msg, processed_at: Time.zone.now)
      @batch.increment!(:failed_invoices)
      @batch.update!(status: :failed, error_message: error_msg)
    end

    def block_remaining(failed_join)
      @batch.batch_arca_process_invoices
            .joins(:invoice)
            .where.not(id: failed_join.id)
            .where(arca_status: %w[pending processing])
            .update_all(arca_status: "blocked")
    end

    def send_service(invoice)
      arca_module.const_get(:SendToArcaService).new(invoice: invoice)
    end

    def arca_module
      Rails.env.production? ? Invoices::Production : Invoices::Development
    end
  end
end
