module BatchInvoiceProcessCreators
  class FinalConsumer
    Result = Struct.new(:batch, :errors, keyword_init: true) do
      def success? = errors.empty?
    end

    def self.call(user:, permitted_params:, item_ids:)
      new(user: user, permitted_params: permitted_params, item_ids: item_ids).call
    end

    def initialize(user:, permitted_params:, item_ids:)
      @user             = user
      @permitted_params = permitted_params
      @item_ids         = item_ids
    end

    def call
      errors = validate
      return Result.new(batch: nil, errors: errors) if errors.any?

      batch = build_batch
      ActiveRecord::Base.transaction do
        batch.save!
        attach_items(batch)
      end
      BulkInvoiceCreationJob.perform_later(batch.id)
      Result.new(batch: batch, errors: [])
    rescue ActiveRecord::RecordInvalid => e
      Result.new(batch: nil, errors: e.record.errors.full_messages)
    end

    private

    attr_reader :user, :permitted_params, :item_ids

    def validate
      errors = []

      if item_ids.empty?
        errors << I18n.t("batch_invoice_processes.errors.item_ids_required")
      elsif item_ids.size > BatchInvoiceProcess::MAX_ITEMS
        errors << I18n.t("batch_invoice_processes.errors.too_many_items", max: BatchInvoiceProcess::MAX_ITEMS)
      else
        owned = Item.where(user_id: user.id, id: item_ids).count
        errors << I18n.t("batch_invoice_processes.errors.invalid_items") if owned != item_ids.size
      end

      errors
    end

    def build_batch
      BatchInvoiceProcess.new(
        permitted_params.merge(
          user_id:      user.id,
          process_type: "final_consumer",
          date:         Date.current,
          period:       Date.current.beginning_of_month
        )
      )
    end

    def attach_items(batch)
      item_ids.each_with_index do |item_id, position|
        BatchInvoiceProcessItem.create!(batch_invoice_process: batch, item_id: item_id, position: position)
      end
    end
  end
end
