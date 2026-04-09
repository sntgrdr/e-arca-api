require 'rails_helper'

RSpec.describe Invoices::PdfGeneratorService, type: :service do
  let(:user) { create(:user) }
  let(:client) { create(:client, user: user) }
  let(:sell_point) { create(:sell_point, user: user, number: '1') }
  let(:iva) { create(:iva, user: user, percentage: 21.0) }
  let(:item) { create(:item, user: user, iva: iva) }

  let(:invoice) do
    inv = create(:client_invoice, :with_cae,
                 user: user,
                 client: client,
                 sell_point: sell_point,
                 invoice_type: 'C',
                 number: '1',
                 date: Date.new(2024, 1, 15),
                 period: Date.new(2024, 1, 1))
    create(:line, lineable: inv, user: user, item: item, iva: iva,
           description: 'Servicio mensual', quantity: 1,
           unit_price: 1000.0, final_price: 1000.0)
    inv
  end

  subject(:service) { described_class.new(invoice: invoice) }

  describe '#call' do
    it 'generates a PDF binary string' do
      pdf = service.call
      expect(pdf).to be_a(String)
      expect(pdf).to be_present
    end

    it 'starts with the PDF magic bytes %PDF' do
      pdf = service.call
      expect(pdf[0..3]).to eq('%PDF')
    end

    it 'raises ArgumentError when invoice has no CAE' do
      invoice_without_cae = create(:client_invoice, :with_lines,
                                   user: user, client: client, sell_point: sell_point)
      service = described_class.new(invoice: invoice_without_cae)
      expect { service.call }.to raise_error(ArgumentError, /CAE/)
    end

    context 'with a type C invoice' do
      it 'generates successfully' do
        expect { service.call }.not_to raise_error
      end
    end

    context 'with a type A invoice' do
      let(:invoice) do
        inv = create(:client_invoice, :with_cae,
                     user: user,
                     client: client,
                     sell_point: sell_point,
                     invoice_type: 'A',
                     number: '2',
                     date: Date.new(2024, 2, 1),
                     period: Date.new(2024, 2, 1))
        create(:line, lineable: inv, user: user, item: item, iva: iva,
               description: 'Consultoria', quantity: 1,
               unit_price: 1000.0, final_price: 1210.0)
        inv
      end

      it 'generates a PDF with %PDF magic bytes' do
        pdf = service.call
        expect(pdf[0..3]).to eq('%PDF')
      end
    end

    context 'with multiple lines' do
      before do
        create(:line, lineable: invoice, user: user, item: item, iva: iva,
               description: 'Segunda linea', quantity: 2,
               unit_price: 500.0, final_price: 1000.0)
      end

      it 'generates a PDF without errors' do
        expect { service.call }.not_to raise_error
      end

      it 'returns a PDF binary' do
        pdf = service.call
        expect(pdf[0..3]).to eq('%PDF')
      end
    end
  end
end
