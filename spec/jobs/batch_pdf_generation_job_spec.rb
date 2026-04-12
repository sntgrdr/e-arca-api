require 'rails_helper'

RSpec.describe BatchPdfGenerationJob, type: :job do
  include ActiveJob::TestHelper

  let(:user)       { create(:user) }
  let(:sell_point) { create(:sell_point, user: user) }
  let(:iva)        { create(:iva, user: user) }
  let(:item)       { create(:item, user: user, iva: iva) }
  let(:batch) do
    create(:batch_invoice_process, :completed,
           user: user,
           sell_point: sell_point,
           item: item)
  end

  let(:fake_zip_data) { "PK\x00fake_zip_content" }

  before do
    allow_any_instance_of(Invoices::BatchPdfZipGeneratorService)
      .to receive(:call)
      .and_return(fake_zip_data)
  end

  def perform_job
    described_class.new.perform(batch.id, user.id)
  end

  describe 'happy path' do
    it 'calls BatchPdfZipGeneratorService with the batch' do
      expect_any_instance_of(Invoices::BatchPdfZipGeneratorService)
        .to receive(:call)
        .and_return(fake_zip_data)

      perform_job
    end

    it 'attaches the ZIP to the batch as pdf_zip' do
      perform_job
      expect(batch.reload.pdf_zip).to be_attached
    end

    it 'attaches the ZIP with the correct filename' do
      perform_job
      expect(batch.reload.pdf_zip.filename.to_s).to eq("facturas_lote_#{batch.id}.zip")
    end

    it 'sets pdf_generated to true' do
      expect { perform_job }
        .to change { batch.reload.pdf_generated }
        .from(false)
        .to(true)
    end
  end

  describe 'when batch does not exist' do
    it 'is discarded (does not propagate the error) when enqueued through the test adapter' do
      described_class.perform_later(0, user.id)
      expect do
        perform_enqueued_jobs
      end.not_to raise_error
    end
  end

  describe 'when the zip generator raises' do
    before do
      allow_any_instance_of(Invoices::BatchPdfZipGeneratorService)
        .to receive(:call)
        .and_raise(StandardError, 'Prawn exploded')
    end

    it 're-raises the error so Solid Queue can retry' do
      expect { perform_job }.to raise_error(StandardError, 'Prawn exploded')
    end

    it 'does not set pdf_generated to true' do
      begin
        perform_job
      rescue StandardError
        nil
      end

      expect(batch.reload.pdf_generated).to be(false)
    end
  end
end
