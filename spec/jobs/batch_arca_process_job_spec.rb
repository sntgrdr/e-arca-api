require "rails_helper"

RSpec.describe BatchArcaProcessJob, type: :job do
  let(:user)       { create(:user) }
  let(:sell_point) { create(:sell_point, user: user) }
  let(:batch)      { create(:batch_arca_process, user: user, sell_point: sell_point, status: :pending) }

  before do
    allow(BatchArca::ProcessorService).to receive_message_chain(:new, :call)
    allow(ApplicationRecord.connection).to receive(:exec_query)
      .with(/pg_try_advisory_lock/, anything, anything)
      .and_return([{ "pg_try_advisory_lock" => true }])
    allow(ApplicationRecord.connection).to receive(:exec_query)
      .with(/pg_advisory_unlock/, anything, anything)
      .and_return([{}])
  end

  describe "#perform" do
    it "calls BatchArca::ProcessorService with the batch" do
      processor = instance_double(BatchArca::ProcessorService)
      expect(BatchArca::ProcessorService).to receive(:new).with(batch).and_return(processor)
      expect(processor).to receive(:call)
      described_class.new.perform(batch.id)
    end

    it "discards silently when batch does not exist" do
      expect { described_class.perform_now(99999) }.not_to raise_error
    end

    it "skips processing when batch is already processing" do
      batch.update!(status: :processing)
      expect(BatchArca::ProcessorService).not_to receive(:new)
      described_class.new.perform(batch.id)
    end

    it "skips processing when batch is already completed" do
      batch.update!(status: :completed)
      expect(BatchArca::ProcessorService).not_to receive(:new)
      described_class.new.perform(batch.id)
    end

    it "releases the advisory lock in the ensure block even if ProcessorService raises" do
      allow(BatchArca::ProcessorService).to receive_message_chain(:new, :call).and_raise(RuntimeError, "boom")
      expect(ApplicationRecord.connection).to receive(:exec_query)
        .with(/pg_advisory_unlock/, anything, anything)
      expect { described_class.new.perform(batch.id) }.to raise_error(RuntimeError, "boom")
    end

    context "when advisory lock cannot be acquired" do
      before do
        allow(ApplicationRecord.connection).to receive(:exec_query)
          .with(/pg_try_advisory_lock/, anything, anything)
          .and_return([{ "pg_try_advisory_lock" => false }])
      end

      it "marks the batch as failed with the lock-contention error message" do
        described_class.new.perform(batch.id)
        expect(batch.reload.status).to eq("failed")
        expect(batch.reload.error_message).to match(/Another batch is already processing/)
      end

      it "does not call ProcessorService" do
        expect(BatchArca::ProcessorService).not_to receive(:new)
        described_class.new.perform(batch.id)
      end
    end
  end
end
