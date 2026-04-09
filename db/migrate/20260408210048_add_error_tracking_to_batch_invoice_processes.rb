class AddErrorTrackingToBatchInvoiceProcesses < ActiveRecord::Migration[8.1]
  def change
    add_column :batch_invoice_processes, :failed_invoices, :integer, default: 0, null: false
    add_column :batch_invoice_processes, :error_details, :jsonb, default: []
  end
end
