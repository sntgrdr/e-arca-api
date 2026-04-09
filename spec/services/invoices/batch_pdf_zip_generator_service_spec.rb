require 'rails_helper'
require 'zip'

RSpec.describe Invoices::BatchPdfZipGeneratorService, type: :service do
  let(:user) { create(:user) }
  let(:client) { create(:client, user: user) }
  let(:sell_point) { create(:sell_point, user: user, number: '1') }
  let(:iva) { create(:iva, user: user, percentage: 21.0) }
  let(:item) { create(:item, user: user, iva: iva) }

  let(:batch_process) do
    create(:batch_invoice_process, user: user, item: item, sell_point: sell_point)
  end

  def create_invoice_with_cae(number:)
    inv = create(:client_invoice, :with_cae,
                 user: user,
                 client: client,
                 sell_point: sell_point,
                 batch_invoice_process: batch_process,
                 invoice_type: 'C',
                 number: number,
                 date: Date.new(2024, 3, 1),
                 period: Date.new(2024, 3, 1))
    create(:line, lineable: inv, user: user, item: item, iva: iva,
           description: 'Servicio', quantity: 1,
           unit_price: 1000.0, final_price: 1000.0)
    inv
  end

  let(:fake_pdf) { "%PDF-1.4 fake pdf content" }

  before do
    # Mock PdfGeneratorService to avoid running real Prawn rendering in this spec
    allow(Invoices::PdfGeneratorService).to receive(:new).and_wrap_original do |original, invoice:|
      instance = original.call(invoice: invoice)
      allow(instance).to receive(:call).and_return(fake_pdf)
      instance
    end
  end

  subject(:service) { described_class.new(batch_process: batch_process) }

  describe '#call' do
    context 'when the batch has no invoices with a CAE' do
      it 'returns a valid (empty) ZIP binary' do
        result = service.call
        expect(result).to be_a(String)
      end

      it 'produces a ZIP with zero entries' do
        result = service.call
        zip_entries = []
        Zip::InputStream.open(StringIO.new(result)) do |io|
          while (entry = io.get_next_entry)
            zip_entries << entry.name
          end
        end
        expect(zip_entries).to be_empty
      end
    end

    context 'when the batch has one invoice with a CAE' do
      let!(:invoice) { create_invoice_with_cae(number: '1') }

      it 'returns a binary String' do
        result = service.call
        expect(result).to be_a(String)
        expect(result).to be_present
      end

      it 'produces a ZIP with one entry' do
        result = service.call
        zip_entries = []
        Zip::InputStream.open(StringIO.new(result)) do |io|
          while (entry = io.get_next_entry)
            zip_entries << entry.name
          end
        end
        expect(zip_entries.size).to eq(1)
      end

      it 'names the entry with factura, type, number and client name' do
        result = service.call
        zip_entries = []
        Zip::InputStream.open(StringIO.new(result)) do |io|
          while (entry = io.get_next_entry)
            zip_entries << entry.name
          end
        end
        expect(zip_entries.first).to match(/\Afactura_C_\d+_.*\.pdf\z/)
      end

      it 'calls PdfGeneratorService for the invoice' do
        service.call
        expect(Invoices::PdfGeneratorService).to have_received(:new).with(invoice: invoice)
      end
    end

    context 'when the batch has multiple invoices with CAEs' do
      let!(:invoice_1) { create_invoice_with_cae(number: '1') }
      let!(:invoice_2) { create_invoice_with_cae(number: '2') }
      let!(:invoice_3) { create_invoice_with_cae(number: '3') }

      it 'produces a ZIP with one entry per invoice' do
        result = service.call
        zip_entries = []
        Zip::InputStream.open(StringIO.new(result)) do |io|
          while (entry = io.get_next_entry)
            zip_entries << entry.name
          end
        end
        expect(zip_entries.size).to eq(3)
      end

      it 'calls PdfGeneratorService for each invoice' do
        service.call
        expect(Invoices::PdfGeneratorService).to have_received(:new).exactly(3).times
      end
    end

    context 'when the batch has invoices both with and without CAE' do
      let!(:invoice_with_cae) { create_invoice_with_cae(number: '1') }
      let!(:invoice_without_cae) do
        create(:client_invoice,
               user: user,
               client: client,
               sell_point: sell_point,
               batch_invoice_process: batch_process,
               invoice_type: 'C',
               number: '2',
               date: Date.current,
               period: Date.current)
      end

      it 'only includes invoices with a CAE in the ZIP' do
        result = service.call
        zip_entries = []
        Zip::InputStream.open(StringIO.new(result)) do |io|
          while (entry = io.get_next_entry)
            zip_entries << entry.name
          end
        end
        expect(zip_entries.size).to eq(1)
      end
    end
  end
end
