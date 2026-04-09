# HARDEN-012: Test Coverage for ARCA Services

## Priority: P2 — Important
## Size: Large (6-8 hours)
## Theme: Quality & Reliability

---

## Problem Statement
The ARCA integration is the core business logic — 15 service classes, zero test coverage. Any change requires manual testing against AFIP's unreliable sandbox.

### Services to test (by priority):

**Tier 1 — AFIP integration (critical)**:
| Service | File | Key Logic |
|---------|------|-----------|
| `Production::SendToArcaService` | `app/services/invoices/production/send_to_arca_service.rb` | SOAP call, XML parsing, CAE extraction, persist success/error |
| `Development::SendToArcaService` | `app/services/invoices/development/send_to_arca_service.rb` | Same flow, different URL |
| `Production::AuthWithArcaService` | `app/services/invoices/production/auth_with_arca_service.rb` | Token auth, caching, certificate signing |
| `Development::AuthWithArcaService` | `app/services/invoices/development/auth_with_arca_service.rb` | Token auth, file-based caching |
| `Production::GetLastInvoiceService` | `app/services/invoices/production/get_last_invoice_service.rb` | AFIP query |
| `Development::GetLastInvoiceService` | `app/services/invoices/development/get_last_invoice_service.rb` | Same |

**Tier 2 — Payload builders**:
| Service | File | Key Logic |
|---------|------|-----------|
| `FeCaePayloadBuilderService` | `app/services/invoices/fe_cae_payload_builder_service.rb` | XML generation for all invoice types |
| `Production::GenerateLoginTicketService` | `app/services/invoices/production/generate_login_ticket_service.rb` | XML login ticket |
| `Development::GenerateLoginTicketService` | `app/services/invoices/development/generate_login_ticket_service.rb` | Same |
| `Production::LastInvoiceQueryService` | `app/services/invoices/production/last_invoice_query_service.rb` | Query builder |

**Tier 3 — PDF generation**:
| Service | File | Key Logic |
|---------|------|-----------|
| `PdfGeneratorService` | `app/services/invoices/pdf_generator_service.rb` | Prawn PDF + QR code |
| `BatchPdfZipGeneratorService` | `app/services/invoices/batch_pdf_zip_generator_service.rb` | ZIP of PDFs |

**Tier 4 — Filter services** (moved to HARDEN-017):
| Service | File |
|---------|------|
| `ClientsFilterService` | `app/services/filters/clients_filter_service.rb` |
| `ItemsFilterService` | `app/services/filters/items_filter_service.rb` |
| `ClientInvoicesFilterService` | `app/services/filters/client_invoices_filter_service.rb` |

## Files to Create

| File | Covers |
|------|--------|
| `spec/services/invoices/production/send_to_arca_service_spec.rb` | SOAP call, response parsing, persist |
| `spec/services/invoices/development/send_to_arca_service_spec.rb` | Same for dev |
| `spec/services/invoices/production/auth_with_arca_service_spec.rb` | Auth flow, caching |
| `spec/services/invoices/development/auth_with_arca_service_spec.rb` | Auth flow, file caching |
| `spec/services/invoices/fe_cae_payload_builder_service_spec.rb` | XML generation |
| `spec/services/invoices/pdf_generator_service_spec.rb` | PDF output |
| `spec/services/invoices/batch_pdf_zip_generator_service_spec.rb` | ZIP output |
| Additional specs for remaining services | As needed |

## Implementation Steps

### Step 1: Add WebMock to Gemfile (if not already present)
```ruby
group :test do
  gem 'webmock', '~> 3.23'
end
```

### Step 2: Test `SendToArcaService` (production)
Use WebMock to stub the Faraday POST to AFIP:

```ruby
RSpec.describe Invoices::Production::SendToArcaService do
  let(:user) { create(:user, legal_number: "20-12345678-9") }
  let(:invoice) { create(:client_invoice, user: user, cae: nil) }
  subject { described_class.new(invoice: invoice) }

  before do
    # Stub auth service
    allow(Invoices::Production::AuthWithArcaService).to receive_message_chain(:new, :call)
      .and_return(["token123", "sign456"])
  end

  context "when AFIP approves" do
    before do
      stub_request(:post, "https://servicios1.afip.gov.ar/wsfev1/service.asmx")
        .to_return(status: 200, body: afip_success_xml)
    end

    it "updates invoice with CAE and returns success" do
      result = subject.call
      expect(result[:success]).to be true
      expect(invoice.reload.cae).to be_present
      expect(invoice.afip_result).to eq("A")
    end
  end

  context "when AFIP rejects" do
    before do
      stub_request(:post, "https://servicios1.afip.gov.ar/wsfev1/service.asmx")
        .to_return(status: 200, body: afip_rejection_xml)
    end

    it "returns error and sets afip_result to R" do
      result = subject.call
      expect(result[:success]).to be false
      expect(invoice.reload.afip_result).to eq("R")
    end
  end

  context "when invoice already has CAE" do
    let(:invoice) { create(:client_invoice, user: user, cae: "existing_cae") }

    it "returns invoice without calling AFIP" do
      result = subject.call
      expect(result).to eq(invoice)
      expect(WebMock).not_to have_requested(:post, /afip/)
    end
  end

  # Helper: build sample AFIP XML responses as fixtures
  def afip_success_xml
    # Return a realistic AFIP FECAESolicitar success response XML
  end
end
```

### Step 3: Test `FeCaePayloadBuilderService`
```ruby
RSpec.describe Invoices::FeCaePayloadBuilderService do
  # Test with invoice type A, B, C
  # Verify XML structure: correct SOAP envelope, FeCabReq, FeDetReq
  # Verify IVA calculations match expected totals
  # Verify all required AFIP fields are present
end
```

### Step 4: Test `PdfGeneratorService`
```ruby
RSpec.describe Invoices::PdfGeneratorService do
  it "generates a PDF without errors" do
    invoice = create(:client_invoice, :with_cae)  # needs factory trait
    pdf_data = described_class.new(invoice: invoice).call
    expect(pdf_data).to be_present
    expect(pdf_data[0..3]).to eq("%PDF")  # PDF magic bytes
  end
end
```

### Step 5: Create AFIP response fixtures
Create `spec/fixtures/afip/` with sample XML responses:
- `fe_cae_solicitar_success.xml`
- `fe_cae_solicitar_rejection.xml`
- `fe_cae_solicitar_error.xml`
- `wsaa_login_success.xml`

### Suggested sub-task split:
1. Filter services (2h) — covered by HARDEN-017
2. PDF services (1h)
3. Payload builder (2h)
4. AFIP integration services (3h)

## Acceptance Criteria
1. Every service in `app/services/invoices/` has a corresponding spec file
2. AFIP services use WebMock stubs (no real HTTP calls in tests)
3. `FeCaePayloadBuilderService` tests verify XML structure for invoice types A, B, C
4. `PdfGeneratorService` test verifies PDF generation succeeds
5. All service specs run offline (no external dependencies)
6. Code coverage for `app/services/invoices/` reaches at least 80%
7. `bundle exec rspec` passes

## Risks
- **VCR vs WebMock**: WebMock is simpler for this case since we control the XML. VCR is better if you want to record real sandbox responses.
- **Certificate dependencies**: Auth service tests need to mock OpenSSL signing (`Open3.capture3`).
- **Test data**: Services need invoices with lines, items, IVAs, sell points. Use complete factories.

## Dependencies
- Benefits from HARDEN-006 (standardized error handling) being done first

## Out of Scope
- Integration tests against live AFIP sandbox
- Performance testing
- Filter service tests (HARDEN-017)
