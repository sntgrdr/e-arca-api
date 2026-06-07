require 'rails_helper'

RSpec.describe Lines::ApplyAdjustmentsService do
  let(:user)       { create(:user, adjustments_enabled: true) }
  let(:iva)        { create(:iva, user: user, percentage: 21) }
  let(:client)     { create(:client, user: user) }
  let(:item)       { create(:item, user: user, iva: iva, price: 1000) }
  let(:sell_point) { create(:sell_point, user: user) }
  let(:invoice)    { create(:client_invoice, user: user, client: client, sell_point: sell_point) }

  def run
    described_class.new(invoice: invoice, user: user).call
  end

  context 'when no adjustment exists for the client/item pair' do
    it 'creates no adjustment lines' do
      expect { run }.not_to change { invoice.lines.where(line_type: 'adjustment').count }
    end

    it 'clears snapshot columns on the item line' do
      item_line = invoice.lines.where(line_type: 'item').first
      item_line.update_columns(original_price: 1000, calculated_price: 900,
                               applied_adjustment_id: 99, applied_adjustment_type: 'discount',
                               applied_adjustment_amount: 100)
      run
      expect(item_line.reload.original_price).to be_nil
      expect(item_line.reload.applied_adjustment_id).to be_nil
    end
  end

  context 'when a percentage discount applies' do
    let!(:adjustment) do
      create(:adjustment, user: user, target: client,
             adjustment_type: 'discount', calculation_type: 'percentage',
             amount: 10, start_date: 1.day.ago)
    end

    it 'creates one discount adjustment line' do
      expect { run }.to change { invoice.lines.where(line_type: 'adjustment').count }.by(1)
    end

    it 'sets a negative final_price on the discount line' do
      run
      adj_line = invoice.lines.find_by(line_type: 'adjustment')
      expect(adj_line.final_price).to be < 0
    end

    it 'populates snapshot columns on the item line' do
      run
      item_line = invoice.lines.where(line_type: 'item').first.reload
      expect(item_line.original_price).to eq(item_line.unit_price)
      expect(item_line.calculated_price).not_to be_nil
      expect(item_line.applied_adjustment_id).to eq(adjustment.id)
      expect(item_line.applied_adjustment_type).to eq('discount')
    end

    it 'uses the invoice date for resolution' do
      future_adj = create(:adjustment, user: user, target: client,
                          adjustment_type: 'discount', calculation_type: 'percentage',
                          amount: 50, start_date: 1.year.from_now)
      run
      adj_line = invoice.lines.find_by(line_type: 'adjustment')
      expect(adj_line.applied_adjustment_id).to eq(adjustment.id)
      expect(adj_line.applied_adjustment_id).not_to eq(future_adj.id)
    end
  end

  context 'when a surcharge applies' do
    let!(:adjustment) do
      create(:adjustment, user: user, target: client,
             adjustment_type: 'surcharge', calculation_type: 'percentage',
             amount: 5, start_date: 1.day.ago)
    end

    it 'creates one surcharge adjustment line with positive final_price' do
      run
      adj_line = invoice.lines.find_by(line_type: 'adjustment')
      expect(adj_line.applied_adjustment_type).to eq('surcharge')
      expect(adj_line.final_price).to be > 0
    end
  end

  context 'when both discount and surcharge apply' do
    let!(:discount) do
      create(:adjustment, user: user, target: client,
             adjustment_type: 'discount', calculation_type: 'percentage',
             amount: 10, start_date: 1.day.ago)
    end
    let!(:surcharge) do
      create(:adjustment, user: user, target: client,
             adjustment_type: 'surcharge', calculation_type: 'percentage',
             amount: 5, start_date: 1.day.ago)
    end

    it 'creates two adjustment lines' do
      expect { run }.to change { invoice.lines.where(line_type: 'adjustment').count }.by(2)
    end
  end

  context 'when called a second time (idempotency on update)' do
    let!(:adjustment) do
      create(:adjustment, user: user, target: client,
             adjustment_type: 'discount', calculation_type: 'percentage',
             amount: 10, start_date: 1.day.ago)
    end

    it 'replaces old adjustment lines instead of duplicating' do
      run
      run
      expect(invoice.lines.where(line_type: 'adjustment').count).to eq(1)
    end
  end

  context 'when adjustments_enabled is false' do
    let(:user) { create(:user, adjustments_enabled: false) }

    let!(:adjustment) do
      create(:adjustment, user: user, target: client,
             adjustment_type: 'discount', calculation_type: 'percentage',
             amount: 10, start_date: 1.day.ago)
    end

    it 'creates no adjustment lines' do
      expect { run }.not_to change { invoice.lines.where(line_type: 'adjustment').count }
    end

    it 'clears snapshot columns on item lines' do
      item_line = invoice.lines.where(line_type: 'item').first
      item_line.update_columns(original_price: 1000, calculated_price: 900,
                               applied_adjustment_id: 99, applied_adjustment_type: 'discount',
                               applied_adjustment_amount: 100)
      run
      item_line.reload
      expect(item_line.original_price).to be_nil
      expect(item_line.applied_adjustment_id).to be_nil
    end
  end
end
