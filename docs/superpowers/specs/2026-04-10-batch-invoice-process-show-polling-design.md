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

**`BatchInvoiceProcessSerializer`** (existing, updated)
Used by `index`. Updated to include slim `item` and `sell_point` associations so the list view can display meaningful context without a separate request.

Attributes:
```
id, status, date, period, total_invoices, processed_invoices, failed_invoices,
pdf_generated, error_message, client_group_id, item_id, sell_point_id, created_at
```

Associations added:
- `item` — `{ id, name, code }`
- `sell_point` — `{ id, number }`

`index` controller query gets `includes(:item, :sell_point)` to prevent N+1.

**`BatchInvoiceProcessDetailSerializer`** (new)
Used by `show` only. Adds a `client_invoices` array using a dedicated slim serializer.

Attributes returned by `BatchInvoiceProcessDetailSerializer`:
```
id, status, date, period, total_invoices, processed_invoices, failed_invoices,
pdf_generated, error_message, client_group_id, item_id, sell_point_id, created_at,
client_invoices
```

`error_details` is included only when `status == "failed"` — it can be verbose and is irrelevant during normal completion.

**`BatchClientInvoiceSerializer`** (new)
Slim invoice shape used only inside the batch show response. Does not reuse `ClientInvoiceSerializer` (which is too heavy — includes lines, credit notes, etc.).

Fields:
```
id, number, date, client_name, client_legal_number, cae, afip_authorized_at, total_price
```

`client_name` and `client_legal_number` are delegated from the associated `Client` record.

Hard cap: `client_invoices` is limited to 200 records ordered by `created_at ASC`. This prevents unbounded payloads for large batches. If a batch exceeds 200 invoices the cap is transparent to the UI — it shows progress counters from the batch record itself, not the invoice count.

---

### Controller

**`set_batch_process`** — unchanged. No `includes` here — actions like `generate_pdfs` and `download_pdfs` don't need invoices and shouldn't pay for the eager load.

```ruby
def set_batch_process
  @batch_process = BatchInvoiceProcess.where(user_id: current_user.id).find(params[:id])
end
```

**`show`** — loads invoices independently, switches to detail serializer, sets `Cache-Control: no-store`:

```ruby
def show
  authorize @batch_process
  batch = BatchInvoiceProcess
    .includes(client_invoices: :client)
    .find(@batch_process.id)
  response.set_header('Cache-Control', 'no-store')
  render json: batch, serializer: BatchInvoiceProcessDetailSerializer
end
```

**`index`** — adds `includes(:item, :sell_point)` for the enriched serializer:

```ruby
def index
  processes = policy_scope(BatchInvoiceProcess)
    .includes(:item, :sell_point)
    .order(created_at: :desc)
  render json: processes, each_serializer: BatchInvoiceProcessSerializer
end
```

**`create`** — unchanged. Returns the batch with `id` so the frontend can navigate to `show`.

---

## Data Flow

```
Frontend (polling GET /api/v1/batch_invoice_processes/:id every ~4s)
  → BatchInvoiceProcessesController#show
  → set_batch_process: loads batch scoped to current_user (no includes)
  → authorize
  → second load with includes(client_invoices: :client), capped at 200
  → Cache-Control: no-store header
  → BatchInvoiceProcessDetailSerializer
      → scalar batch fields
      → error_details only if status == "failed"
      → client_invoices: [BatchClientInvoiceSerializer, ...] (max 200)
  → JSON response
Frontend stops polling when status == "completed" || "failed"
```

---

## Error Handling

No new error cases introduced. The existing `set_batch_process` already raises `ActiveRecord::RecordNotFound` (→ 404) if the batch doesn't belong to `current_user`. The `includes` does not change this behaviour.

---

## Testing

**Request spec additions to `spec/requests/batch_invoice_processes_spec.rb`:**

`show`:
- Returns `client_invoices` nested in the response with slim fields: `id`, `number`, `client_name`, `client_legal_number`, `cae`, `afip_authorized_at`, `total_price`
- Returns `error_details` when `status == "failed"`
- Does NOT return `error_details` when `status == "completed"`
- Response includes `Cache-Control: no-store` header
- Returns at most 200 invoices when batch has more than 200

`index`:
- Returns `item` and `sell_point` nested in each result
- Does NOT include `client_invoices` (regression guard)

Tenant isolation: covered by existing shared examples (no change needed).

No new model specs — no model logic is changed.
