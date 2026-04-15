module BatchInvoiceProcessCreators
  class PerClient
    Result = Struct.new(:batch, :errors, keyword_init: true) do
      def success? = errors.empty?
    end

    def self.call(user:, permitted_params:, item_ids:, client_ids:)
      new(user: user, permitted_params: permitted_params,
          item_ids: item_ids, client_ids: client_ids).call
    end

    def initialize(user:, permitted_params:, item_ids:, client_ids:)
      @user            = user
      @permitted_params = permitted_params
      @item_ids         = item_ids
      @client_ids       = client_ids
    end

    def call
      errors = validate
      return Result.new(batch: nil, errors: errors) if errors.any?

      batch = build_batch
      ActiveRecord::Base.transaction do
        batch.save!
        attach_items(batch)
        attach_clients(batch)
      end
      BulkInvoiceCreationJob.perform_later(batch.id)
      Result.new(batch: batch, errors: [])
    rescue ActiveRecord::RecordInvalid => e
      Result.new(batch: nil, errors: e.record.errors.full_messages)
    end

    private

    attr_reader :user, :permitted_params, :item_ids, :client_ids

    def validate
      errors = []

      if item_ids.any?
        if item_ids.size > BatchInvoiceProcess::MAX_ITEMS
          errors << I18n.t("batch_invoice_processes.errors.too_many_items",
                           max: BatchInvoiceProcess::MAX_ITEMS)
        else
          owned = Item.where(user_id: user.id, id: item_ids).count
          errors << I18n.t("batch_invoice_processes.errors.invalid_items") if owned != item_ids.size
        end
      end

      if client_ids.any?
        if client_ids.size > BatchInvoiceProcess::MAX_CLIENTS
          errors << I18n.t("batch_invoice_processes.errors.too_many_clients",
                           max: BatchInvoiceProcess::MAX_CLIENTS)
        else
          group_id = permitted_params[:client_group_id]
          scope = if group_id.present?
            Client.where(user_id: user.id, id: client_ids, client_group_id: group_id)
          else
            Client.where(user_id: user.id, id: client_ids)
          end

          errors << I18n.t("batch_invoice_processes.errors.invalid_clients") if scope.count != client_ids.size
        end
      else
        group_id = permitted_params[:client_group_id]
        resolved_count = if group_id.present?
          ClientGroup.where(user_id: user.id, id: group_id)
                     .first&.clients&.where(active: true)&.count.to_i
        else
          Client.all_my_clients(user.id).active.count
        end

        if resolved_count > BatchInvoiceProcess::MAX_CLIENTS
          errors << I18n.t("batch_invoice_processes.errors.too_many_resolved_clients",
                           count: resolved_count, max: BatchInvoiceProcess::MAX_CLIENTS)
        end
      end

      errors
    end

    def build_batch
      build_params = permitted_params.merge(user_id: user.id, process_type: "per_client")
      build_params[:item_id] = item_ids.first if item_ids.any? && build_params[:item_id].blank?
      BatchInvoiceProcess.new(build_params)
    end

    def attach_items(batch)
      item_ids.each_with_index do |item_id, position|
        BatchInvoiceProcessItem.create!(batch_invoice_process: batch, item_id: item_id, position: position)
      end
    end

    def attach_clients(batch)
      client_ids.each do |client_id|
        BatchInvoiceProcessClient.create!(batch_invoice_process: batch, client_id: client_id)
      end
    end
  end
end
