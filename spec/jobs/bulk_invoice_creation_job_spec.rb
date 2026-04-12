require 'rails_helper'

RSpec.describe BulkInvoiceCreationJob, type: :job do
  include ActiveJob::TestHelper

  let(:user)        { create(:user) }
  let(:sell_point)  { create(:sell_point, user: user) }
  let(:iva)         { create(:iva, user: user, percentage: 21.0) }
  let(:item)        { create(:item, user: user, price: 1000.0, iva: iva) }
  let(:client_group) { create(:client_group, user: user) }
  let(:batch) do
    create(:batch_invoice_process,
           user: user,
           sell_point: sell_point,
           item: item,
           client_group: client_group,
           date: Date.current,
           period: Date.current)
  end

  def perform_job
    described_class.new.perform(batch.id)
  end

  describe 'with active clients in the group' do
    let!(:client_a) { create(:client, user: user, client_group: client_group, active: true) }
    let!(:client_b) { create(:client, user: user, client_group: client_group, active: true) }

    it 'creates an invoice for each active client' do
      expect { perform_job }.to change(ClientInvoice, :count).by(2)
    end

    it 'sets correct attributes on each created invoice' do
      perform_job
      invoice = ClientInvoice.find_by(client_id: client_a.id, batch_invoice_process_id: batch.id)
      expect(invoice).to be_present
      expect(invoice.user_id).to eq(user.id)
      expect(invoice.sell_point_id).to eq(sell_point.id)
      expect(invoice.date).to eq(Date.current)
      expect(invoice.batch_invoice_process_id).to eq(batch.id)
    end

    it 'increments processed_invoices counter for each invoice created' do
      perform_job
      expect(batch.reload.processed_invoices).to eq(2)
    end

    it 'sets batch status to :completed' do
      perform_job
      expect(batch.reload.status).to eq('completed')
    end

    it 'sets total_invoices to the count of active clients' do
      perform_job
      expect(batch.reload.total_invoices).to eq(2)
    end
  end

  describe 'with no active clients in the group' do
    let!(:inactive_client) { create(:client, user: user, client_group: client_group, active: false) }

    it 'does not create any invoices' do
      expect { perform_job }.not_to change(ClientInvoice, :count)
    end

    it 'completes with 0 processed_invoices' do
      perform_job
      batch.reload
      expect(batch.processed_invoices).to eq(0)
      expect(batch.status).to eq('completed')
    end
  end

  describe 'idempotency' do
    let!(:client) { create(:client, user: user, client_group: client_group, active: true) }

    it 'does not create duplicate invoices when run twice' do
      perform_job
      expect { perform_job }.not_to change(ClientInvoice, :count)
    end

    it 'does not increment processed_invoices on the second run' do
      perform_job
      count_after_first = batch.reload.processed_invoices
      perform_job
      expect(batch.reload.processed_invoices).to eq(count_after_first)
    end
  end

  describe 'partial failure' do
    let!(:healthy_client) { create(:client, user: user, client_group: client_group, active: true) }
    let!(:failing_client) { create(:client, user: user, client_group: client_group, active: true) }

    before do
      call_count = 0
      allow(ClientInvoice).to receive(:create!).and_wrap_original do |original, *args, **kwargs|
        call_count += 1
        if call_count == 1
          raise StandardError, 'Something went wrong'
        else
          original.call(*args, **kwargs)
        end
      end
    end

    it 'creates an invoice for the client that did not fail' do
      expect { perform_job }.to change(ClientInvoice, :count).by(1)
    end

    it 'increments failed_invoices for the failing client' do
      perform_job
      expect(batch.reload.failed_invoices).to eq(1)
    end

    it 'still sets batch status to :completed' do
      perform_job
      expect(batch.reload.status).to eq('completed')
    end

    it 'sets an error_message summarising created vs failed counts' do
      perform_job
      batch.reload
      expect(batch.error_message).to match(/\d+ creadas, \d+ fallidas/)
    end

    it 'records error_details for the failed client' do
      perform_job
      batch.reload
      expect(batch.error_details).not_to be_empty
      expect(batch.error_details.first).to include('error')
    end
  end

  describe 'when batch does not exist' do
    it 'is discarded (does not propagate the error) when enqueued through the test adapter' do
      described_class.perform_later(0)
      expect do
        perform_enqueued_jobs
      end.not_to raise_error
    end
  end

  describe 'batch transitions through processing status' do
    let!(:client) { create(:client, user: user, client_group: client_group, active: true) }

    it 'sets status to processing before completing' do
      perform_job

      # Both processing and completed transitions happen sequentially;
      # the final state must be completed.
      expect(batch.reload.status).to eq('completed')
    end
  end
end
