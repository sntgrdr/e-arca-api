require 'zip'

module Invoices
  class BatchPdfZipGeneratorService
    def initialize(batch_process:)
      @batch_process = batch_process
    end

    def call
      invoices = @batch_process.client_invoices.where.not(cae: nil).includes(:client, :sell_point, :user, lines: :iva)

      zip_buffer = Zip::OutputStream.write_buffer do |zip|
        invoices.find_each do |invoice|
          pdf = Invoices::PdfGeneratorService.new(invoice: invoice).call
          filename = "factura_#{invoice.invoice_type}_#{invoice.number}_#{invoice.client.legal_name.parameterize}.pdf"
          zip.put_next_entry(filename)
          zip.write(pdf)
        end
      end

      zip_buffer.rewind
      zip_buffer.read
    end
  end
end
