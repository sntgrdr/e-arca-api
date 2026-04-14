require 'rails_helper'

RSpec.describe CreditNotes::BuildFromInvoiceService, type: :service do
  let(:user)       { create(:user) }
  let(:iva)        { create(:iva, user: user) }
  let(:sell_point) { create(:sell_point, user: user) }
  let(:client)     { create(:client, user: user, iva: iva) }
  let(:item_a)     { create(:item, user: user, iva: iva) }
  let(:item_b)     { create(:item, user: user, iva: iva) }

  # Build an invoice with two explicit lines and no factory interference
  let(:invoice) do
    inv = ClientInvoice.new(
      user: user, client: client, sell_point: sell_point,
      number: '1', date: Date.current, period: Date.current,
      invoice_type: 'C', total_price: 20_000,
      afip_status: :authorized, cae: '12345678901234',
      cae_expiration: 10.days.from_now.to_date,
      afip_invoice_number: '1', afip_result: 'A',
      afip_authorized_at: Time.current
    )
    inv.lines.build(user: user, item: item_a, iva: iva,
                    description: 'Line A', quantity: 1,
                    unit_price: 10_000, final_price: 10_000)
    inv.lines.build(user: user, item: item_b, iva: iva,
                    description: 'Line B', quantity: 1,
                    unit_price: 10_000, final_price: 10_000)
    inv.save!
    inv
  end

  subject(:result) do
    described_class.call(
      user:              user,
      client_invoice_id: invoice.id,
      date:              Date.current.to_s
    )
  end

  describe 'remaining_lines — no previous credit notes' do
    it 'returns all invoice lines at full amount' do
      lines = result.lines
      expect(lines.size).to eq(2)
    end

    it 'preserves original quantities' do
      lines = result.lines
      expect(lines.map(&:quantity).map(&:to_f)).to eq([1.0, 1.0])
    end

    it 'returns lines at full final_price' do
      expect(result.lines.map { |l| l.final_price.to_f }).to contain_exactly(10_000.0, 10_000.0)
    end

    it 'sets total_price equal to sum of line final_prices' do
      expect(result.total_price.to_f).to eq(20_000.0)
    end
  end

  describe 'remaining_lines — with a previous partial credit note' do
    # CN1 credits: Line A = 4,000, Line B = 7,500 (total = 11,500)
    # Remaining:   Line A = 6,000, Line B = 2,500 (total = 8,500)
    let!(:cn1) do
      cn = CreditNote.new(
        user: user, client: client, sell_point: sell_point,
        client_invoice: invoice, number: '1', date: Date.current,
        period: invoice.period, invoice_type: invoice.invoice_type,
        total_price: 11_500, afip_status: :draft
      )
      cn.lines.build(user: user, item: item_a, iva: iva,
                     description: 'Line A', quantity: 1,
                     unit_price: 4_000, final_price: 4_000)
      cn.lines.build(user: user, item: item_b, iva: iva,
                     description: 'Line B', quantity: 1,
                     unit_price: 7_500, final_price: 7_500)
      cn.save!
      cn
    end

    it 'returns remaining amount per item, not proportional total' do
      lines_by_item = result.lines.index_by { |l| l.item_id }
      expect(lines_by_item[item_a.id].final_price.to_f).to eq(6_000.0)
      expect(lines_by_item[item_b.id].final_price.to_f).to eq(2_500.0)
    end

    it 'preserves original quantities' do
      expect(result.lines.map(&:quantity).map(&:to_f)).to contain_exactly(1.0, 1.0)
    end

    it 'adjusts unit_price to match remaining final_price / quantity' do
      lines_by_item = result.lines.index_by { |l| l.item_id }
      expect(lines_by_item[item_a.id].unit_price.to_f).to eq(6_000.0)
      expect(lines_by_item[item_b.id].unit_price.to_f).to eq(2_500.0)
    end

    it 'sets total_price to the remaining balance' do
      expect(result.total_price.to_f).to eq(8_500.0)
    end
  end

  describe 'remaining_lines — with a fully credited line' do
    let!(:cn_full_a) do
      cn = CreditNote.new(
        user: user, client: client, sell_point: sell_point,
        client_invoice: invoice, number: '1', date: Date.current,
        period: invoice.period, invoice_type: invoice.invoice_type,
        total_price: 10_000, afip_status: :draft
      )
      cn.lines.build(user: user, item: item_a, iva: iva,
                     description: 'Line A', quantity: 1,
                     unit_price: 10_000, final_price: 10_000)
      cn.save!
      cn
    end

    it 'excludes the fully credited line' do
      item_ids = result.lines.map(&:item_id)
      expect(item_ids).not_to include(item_a.id)
    end

    it 'includes the uncredited line at full amount' do
      lines_by_item = result.lines.index_by { |l| l.item_id }
      expect(lines_by_item[item_b.id].final_price.to_f).to eq(10_000.0)
    end
  end

  describe 'remaining_lines — invoice fully credited' do
    let!(:cn_full) do
      cn = CreditNote.new(
        user: user, client: client, sell_point: sell_point,
        client_invoice: invoice, number: '1', date: Date.current,
        period: invoice.period, invoice_type: invoice.invoice_type,
        total_price: 20_000, afip_status: :draft
      )
      cn.lines.build(user: user, item: item_a, iva: iva,
                     description: 'Line A', quantity: 1,
                     unit_price: 10_000, final_price: 10_000)
      cn.lines.build(user: user, item: item_b, iva: iva,
                     description: 'Line B', quantity: 1,
                     unit_price: 10_000, final_price: 10_000)
      cn.save!
      cn
    end

    it 'returns a credit note with no lines' do
      expect(result.lines).to be_empty
    end
  end

  describe 'BigDecimal precision — non-divisible unit_price' do
    # Invoice: 1 line, qty=3, final_price=10.0000
    # Remaining: 10.0000 / 3 = 3.3333... → should round to 4dp without float drift
    let(:invoice) do
      inv = ClientInvoice.new(
        user: user, client: client, sell_point: sell_point,
        number: '2', date: Date.current, period: Date.current,
        invoice_type: 'C', total_price: BigDecimal("10.0000"),
        afip_status: :authorized, cae: '99999999999999',
        cae_expiration: 10.days.from_now.to_date,
        afip_invoice_number: '2', afip_result: 'A',
        afip_authorized_at: Time.current
      )
      inv.lines.build(user: user, item: item_a, iva: iva,
                      description: 'Line A', quantity: 3,
                      unit_price: BigDecimal("3.3333"), final_price: BigDecimal("10.0000"))
      inv.save!
      inv
    end

    it 'rounds unit_price to 4 decimal places without float drift' do
      line = result.lines.first
      expect(line.unit_price).to eq(BigDecimal("3.3333"))
    end

    it 'keeps final_price exact' do
      line = result.lines.first
      expect(line.final_price).to eq(BigDecimal("10.0000"))
    end
  end
end
