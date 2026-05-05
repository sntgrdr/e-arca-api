require "rails_helper"

RSpec.describe BatchArcaProcessInvoiceSerializer, type: :serializer do
  let(:user)       { create(:user) }
  let(:sell_point) { create(:sell_point, user: user) }
  let(:iva)        { create(:iva, user: user) }
  let(:client)     { create(:client, user: user, iva: iva) }
  let(:invoice) do
    create(:client_invoice, user: user, sell_point: sell_point, client: client,
           number: "36", afip_invoice_number: "40", cae: "12345678901234",
           total_price: 50_000)
  end
  let(:batch)       { create(:batch_arca_process, user: user, sell_point: sell_point) }
  let(:join_record) do
    create(:batch_arca_process_invoice, batch_arca_process: batch, invoice: invoice,
           arca_status: :failed, arca_error: "ARCA sequence error")
  end

  subject(:json) { described_class.new(join_record).serializable_hash.stringify_keys }

  it "returns invoice.id as id, not the join record id" do
    expect(json["id"]).to eq(invoice.id)
    expect(json["id"]).not_to eq(join_record.id)
  end

  it "returns invoice.number as number, not afip_invoice_number" do
    expect(json["number"]).to eq("36")
    expect(json["number"]).not_to eq("40")
  end

  it "returns invoice.afip_invoice_number" do
    expect(json["afip_invoice_number"]).to eq("40")
  end

  it "returns invoice.cae" do
    expect(json["cae"]).to eq("12345678901234")
  end

  it "returns invoice.total_price" do
    expect(json["total_price"].to_f).to eq(50_000.0)
  end

  it "returns arca_error from the join record, not the invoice" do
    expect(json["arca_error"]).to eq("ARCA sequence error")
  end

  it "returns arca_status from the join record" do
    expect(json["arca_status"]).to eq("failed")
  end

  it "returns client.legal_name as client_name" do
    expect(json["client_name"]).to eq(client.legal_name)
  end

end
