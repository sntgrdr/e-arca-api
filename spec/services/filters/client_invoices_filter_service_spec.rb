require 'rails_helper'

RSpec.describe Filters::ClientInvoicesFilterService, type: :service do
  subject(:filter) { described_class.new(params, scope).call }

  let(:user)       { create(:user) }
  let(:sell_point) { create(:sell_point, user: user) }
  let(:scope)      { ClientInvoice.all }

  describe 'empty/nil params' do
    let!(:invoice_a) { create(:client_invoice, user: user, sell_point: sell_point) }
    let!(:invoice_b) { create(:client_invoice, user: user, sell_point: sell_point) }

    context 'when params is empty hash' do
      let(:params) { {} }

      it 'returns the full unfiltered scope' do
        expect(filter).to include(invoice_a, invoice_b)
      end
    end

    context 'when params values are nil' do
      let(:params) do
        {
          number: nil, date_from: nil, date_to: nil,
          period_from: nil, period_to: nil,
          client_legal_name: nil, total_from: nil, total_to: nil
        }
      end

      it 'returns the full unfiltered scope' do
        expect(filter).to include(invoice_a, invoice_b)
      end
    end
  end

  describe '#filter_by_number' do
    let!(:invoice_001) { create(:client_invoice, user: user, sell_point: sell_point, number: '100') }
    let!(:invoice_002) { create(:client_invoice, user: user, sell_point: sell_point, number: '200') }

    context 'with a partial match' do
      let(:params) { { number: '10' } }

      it 'returns invoices whose number contains the value' do
        expect(filter).to include(invoice_001)
        expect(filter).not_to include(invoice_002)
      end
    end

    context 'with case-insensitive input' do
      let(:params) { { number: '100' } }

      it 'matches the number' do
        expect(filter).to include(invoice_001)
      end
    end
  end

  describe '#filter_by_date_from and #filter_by_date_to' do
    let(:jan_1)   { Date.new(2025, 1, 1) }
    let(:jan_15)  { Date.new(2025, 1, 15) }
    let(:feb_1)   { Date.new(2025, 2, 1) }

    let!(:early)  { create(:client_invoice, user: user, sell_point: sell_point, date: jan_1) }
    let!(:mid)    { create(:client_invoice, user: user, sell_point: sell_point, date: jan_15) }
    let!(:late)   { create(:client_invoice, user: user, sell_point: sell_point, date: feb_1) }

    context 'with date_from only' do
      let(:params) { { date_from: '2025-01-15' } }

      it 'returns invoices on or after the date' do
        expect(filter).to include(mid, late)
        expect(filter).not_to include(early)
      end
    end

    context 'with date_to only' do
      let(:params) { { date_to: '2025-01-15' } }

      it 'returns invoices on or before the date' do
        expect(filter).to include(early, mid)
        expect(filter).not_to include(late)
      end
    end

    context 'with both date_from and date_to' do
      let(:params) { { date_from: '2025-01-15', date_to: '2025-01-15' } }

      it 'returns only the invoice on that exact date' do
        expect(filter).to include(mid)
        expect(filter).not_to include(early, late)
      end
    end
  end

  describe '#filter_by_period_from and #filter_by_period_to' do
    let(:period_jan) { Date.new(2025, 1, 1) }
    let(:period_feb) { Date.new(2025, 2, 1) }
    let(:period_mar) { Date.new(2025, 3, 1) }

    let!(:invoice_jan) { create(:client_invoice, user: user, sell_point: sell_point, period: period_jan) }
    let!(:invoice_feb) { create(:client_invoice, user: user, sell_point: sell_point, period: period_feb) }
    let!(:invoice_mar) { create(:client_invoice, user: user, sell_point: sell_point, period: period_mar) }

    context 'with period_from only' do
      let(:params) { { period_from: '2025-02-01' } }

      it 'returns invoices with period on or after the given period' do
        expect(filter).to include(invoice_feb, invoice_mar)
        expect(filter).not_to include(invoice_jan)
      end
    end

    context 'with period_to only' do
      let(:params) { { period_to: '2025-02-01' } }

      it 'returns invoices with period on or before the given period' do
        expect(filter).to include(invoice_jan, invoice_feb)
        expect(filter).not_to include(invoice_mar)
      end
    end

    context 'with both period_from and period_to' do
      let(:params) { { period_from: '2025-01-01', period_to: '2025-02-01' } }

      it 'returns invoices within the period range' do
        expect(filter).to include(invoice_jan, invoice_feb)
        expect(filter).not_to include(invoice_mar)
      end
    end
  end

  describe '#filter_by_client_legal_name' do
    let(:client_acme)   { create(:client, user: user, legal_name: 'Acme Corp SA') }
    let(:client_globex) { create(:client, user: user, legal_name: 'Globex Solutions SRL') }

    let!(:invoice_acme)   { create(:client_invoice, user: user, sell_point: sell_point, client: client_acme) }
    let!(:invoice_globex) { create(:client_invoice, user: user, sell_point: sell_point, client: client_globex) }

    context 'with a partial match' do
      let(:params) { { client_legal_name: 'acme' } }

      it 'returns invoices whose client legal_name matches partially' do
        expect(filter).to include(invoice_acme)
        expect(filter).not_to include(invoice_globex)
      end
    end

    context 'with case-insensitive input' do
      let(:params) { { client_legal_name: 'GLOBEX' } }

      it 'matches regardless of case' do
        expect(filter).to include(invoice_globex)
        expect(filter).not_to include(invoice_acme)
      end
    end
  end

  describe '#filter_by_total_from and #filter_by_total_to' do
    let!(:low)    { create(:client_invoice, user: user, sell_point: sell_point, total_price: 100.0) }
    let!(:medium) { create(:client_invoice, user: user, sell_point: sell_point, total_price: 1000.0) }
    let!(:high)   { create(:client_invoice, user: user, sell_point: sell_point, total_price: 5000.0) }

    context 'with total_from only' do
      let(:params) { { total_from: '1000' } }

      it 'returns invoices with total_price >= total_from' do
        expect(filter).to include(medium, high)
        expect(filter).not_to include(low)
      end
    end

    context 'with total_to only' do
      let(:params) { { total_to: '1000' } }

      it 'returns invoices with total_price <= total_to' do
        expect(filter).to include(low, medium)
        expect(filter).not_to include(high)
      end
    end

    context 'with both total_from and total_to' do
      let(:params) { { total_from: '500', total_to: '2000' } }

      it 'returns invoices within the amount range' do
        expect(filter).to include(medium)
        expect(filter).not_to include(low, high)
      end
    end
  end

  describe 'combined filters' do
    let(:target_client) { create(:client, user: user, legal_name: 'Target SRL') }
    let!(:target_invoice) do
      create(:client_invoice,
             user: user,
             sell_point: sell_point,
             client: target_client,
             number: '500',
             date: Date.new(2025, 6, 15),
             period: Date.new(2025, 6, 1),
             total_price: 3000.0)
    end
    let!(:other_invoice) do
      create(:client_invoice,
             user: user,
             sell_point: sell_point,
             number: '100',
             date: Date.new(2024, 1, 1),
             total_price: 50.0)
    end

    let(:params) do
      {
        number: '50',
        date_from: '2025-01-01',
        client_legal_name: 'Target',
        total_from: '2000',
        total_to: '4000'
      }
    end

    it 'applies all filters and returns the correct record' do
      expect(filter).to include(target_invoice)
      expect(filter).not_to include(other_invoice)
    end
  end
end
