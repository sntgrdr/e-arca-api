# Feature: BatchInvoiceProcess Show — Polling-Ready Response

## Problem

After creating a batch invoice process, the user is redirected to the show page. While the background job runs and creates `ClientInvoice` records one by one, the show page has no way to display them — the `show` endpoint returns only scalar batch attributes, no associated invoices.

## Solution

Enrich the `show` endpoint to return the full batch state including associated `client_invoices` with a slim shape. The frontend polls this endpoint every few seconds while the batch is `pending` or `processing` and stops when it reaches `completed` or `failed`.

## Scope

Backend only. Frontend polling logic and UI rendering are out of scope for this spec.

## Out of Scope

- ActionCable / WebSocket broadcasting
- Pagination of `client_invoices` within the show response (batches are bounded by the user's client list)
- PDF generation workflow (separate feature)

---

## Architecture

### Serializers

**`BatchInvoiceProcessSerializer`** (existing, unchanged)
Used by `index`. Returns scalar attributes only — no invoices. Stays lightweight for list views.

**`BatchInvoiceProcessDetailSerializer`** (new)
Used by `show` only. Adds a `client_invoices` array using a dedicated slim serializer.

Attributes returned by `BatchInvoiceProcessDetailSerializer`:
```
id, status, date, period, total_invoices, processed_invoices, failed_invoices,
pdf_generated, error_message, error_details, client_group_id, item_id,
sell_point_id, created_at, client_invoices
```

**`BatchClientInvoiceSerializer`** (new)
Slim invoice shape used only inside the batch show response. Does not reuse `ClientInvoiceSerializer` (which is too heavy — includes lines, credit notes, etc.).

Fields:
```
id, number, date, client_name, client_legal_number, cae, afip_authorized_at, total_price
```

`client_name` and `client_legal_number` are delegated from the associated `Client` record.

---

### Controller

**`set_batch_process`** — add `includes` to prevent N+1 when the serializer iterates invoices:

```ruby
def set_batch_process
  @batch_process = BatchInvoiceProcess
    .where(user_id: current_user.id)
    .includes(client_invoices: :client)
    .find(params[:id])
end
```

**`show`** — switch to detail serializer:

```ruby
def show
  authorize @batch_process
  render json: @batch_process, serializer: BatchInvoiceProcessDetailSerializer
end
```

**`create`** — unchanged. Returns the batch with `id` so the frontend can navigate to `show`.

**`index`** — unchanged. Continues using `BatchInvoiceProcessSerializer` (no invoices).

---

## Data Flow

```
Frontend (polling GET /api/v1/batch_invoice_processes/:id every ~4s)
  → BatchInvoiceProcessesController#show
  → loads BatchInvoiceProcess with includes(client_invoices: :client)
  → BatchInvoiceProcessDetailSerializer
      → scalar batch fields
      → client_invoices: [BatchClientInvoiceSerializer, ...]
  → JSON response
Frontend stops polling when status == "completed" || "failed"
```

---

## Error Handling

No new error cases introduced. The existing `set_batch_process` already raises `ActiveRecord::RecordNotFound` (→ 404) if the batch doesn't belong to `current_user`. The `includes` does not change this behaviour.

---

## Testing

**Request spec additions to `spec/requests/batch_invoice_processes_spec.rb`:**

- `GET /api/v1/batch_invoice_processes/:id` returns `client_invoices` nested in the response
- `client_invoices` array includes expected slim fields: `id`, `number`, `client_name`, `client_legal_number`, `cae`, `afip_authorized_at`, `total_price`
- `GET /api/v1/batch_invoice_processes` (index) does NOT include `client_invoices` (regression guard)
- Tenant isolation: covered by existing shared examples (no change needed)

No new model specs — no model logic is changed.
