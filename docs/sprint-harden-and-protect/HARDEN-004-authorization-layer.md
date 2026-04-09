# HARDEN-004: Implement Authorization Layer (Pundit)

## Priority: P0 — Critical
## Size: Medium (4-6 hours)
## Theme: Access Control & Data Isolation

---

## Problem Statement
Data isolation relies on manual `.where(user_id: current_user.id)` in every controller's `set_*` method. There is no centralized authorization framework, no `after_action` enforcement, and no safety net if a developer forgets the scope on a new endpoint.

### Current scoping pattern (repeated in every controller):
```ruby
# app/controllers/api/v1/clients_controller.rb:42
def set_client
  @client = Client.where(user_id: current_user.id).find(params[:id])
end
```

### Controllers that need policies (10 total):
| Controller | File | Scoping Method |
|------------|------|----------------|
| ClientsController | `app/controllers/api/v1/clients_controller.rb:42` | `set_client` |
| ClientGroupsController | `app/controllers/api/v1/client_groups_controller.rb:40` | `set_client_group` |
| ItemsController | `app/controllers/api/v1/items_controller.rb:58` | `set_item` |
| IvasController | `app/controllers/api/v1/ivas_controller.rb:40` | `set_iva` |
| SellPointsController | `app/controllers/api/v1/sell_points_controller.rb:42` | `set_sell_point` |
| ClientInvoicesController | `app/controllers/api/v1/client_invoices_controller.rb:72` | `set_invoice` |
| CreditNotesController | `app/controllers/api/v1/credit_notes_controller.rb:58` | `set_credit_note` |
| BatchInvoiceProcessesController | `app/controllers/api/v1/batch_invoice_processes_controller.rb:59` | `set_batch_process` |
| ProfilesController | `app/controllers/api/v1/profiles_controller.rb` | Uses `current_user` directly |
| RegistrationsController | `app/controllers/api/v1/auth/registrations_controller.rb` | No scoping needed |

## Files to Create/Modify

| File | Action |
|------|--------|
| `Gemfile` | Add `gem 'pundit', '~> 2.4'` |
| `app/controllers/api/v1/base_controller.rb` | Include Pundit, add `after_action :verify_authorized`, add rescue for `Pundit::NotAuthorizedError` |
| `app/policies/application_policy.rb` | Create — base policy class |
| `app/policies/client_policy.rb` | Create |
| `app/policies/client_group_policy.rb` | Create |
| `app/policies/item_policy.rb` | Create |
| `app/policies/iva_policy.rb` | Create |
| `app/policies/sell_point_policy.rb` | Create |
| `app/policies/client_invoice_policy.rb` | Create |
| `app/policies/credit_note_policy.rb` | Create |
| `app/policies/batch_invoice_process_policy.rb` | Create |
| Each controller listed above | Add `authorize @resource` calls |

## Implementation Steps

### Step 1: Install Pundit
```ruby
# Gemfile
gem 'pundit', '~> 2.4'
```
```bash
bundle install
```

### Step 2: Create `app/policies/application_policy.rb`
```ruby
class ApplicationPolicy
  attr_reader :user, :record

  def initialize(user, record)
    @user = user
    @record = record
  end

  def index?    = true
  def show?     = owner?
  def create?   = true
  def update?   = owner?
  def destroy?  = owner?

  private

  def owner?
    record.user_id == user.id
  end

  class Scope
    attr_reader :user, :scope

    def initialize(user, scope)
      @user = user
      @scope = scope
    end

    def resolve
      scope.where(user_id: user.id)
    end
  end
end
```

### Step 3: Create resource policies
Each policy inherits from `ApplicationPolicy`. Most need no customization since all resources follow the `user_id` ownership model. Example:

```ruby
# app/policies/client_policy.rb
class ClientPolicy < ApplicationPolicy; end

# app/policies/client_invoice_policy.rb
class ClientInvoicePolicy < ApplicationPolicy
  def send_to_arca? = owner?
  def download_pdf?  = owner?
end

# app/policies/credit_note_policy.rb
class CreditNotePolicy < ApplicationPolicy
  def send_to_arca? = owner?
end

# app/policies/batch_invoice_process_policy.rb
class BatchInvoiceProcessPolicy < ApplicationPolicy
  def generate_pdfs? = owner?
  def download_pdfs? = owner?
end
```

### Step 4: Update `app/controllers/api/v1/base_controller.rb`
```ruby
module Api
  module V1
    class BaseController < ActionController::API
      include Pagy::Backend
      include Pundit::Authorization

      before_action :authenticate_user!
      after_action :verify_authorized, except: :index
      after_action :verify_policy_scoped, only: :index

      rescue_from Pundit::NotAuthorizedError do |_e|
        render json: {
          error: { code: "forbidden", message: "You are not authorized to perform this action" }
        }, status: :forbidden
      end

      # ... existing rescue_from blocks ...
    end
  end
end
```

### Step 5: Update each controller
Add `authorize` calls. Example for `ClientsController`:
```ruby
def index
  base_scope = policy_scope(Client).active
  filtered = ::Filters::ClientsFilterService.new(params, base_scope).call
  result = paginate(filtered)
  render json: result[:data], meta: result[:pagination], each_serializer: ClientSerializer
end

def show
  authorize @client
  render json: @client, serializer: ClientSerializer
end

def create
  client = Client.new(client_params.merge(user_id: current_user.id))
  authorize client
  # ... rest unchanged
end

def update
  authorize @client
  # ... rest unchanged
end

def destroy
  authorize @client
  # ... rest unchanged
end
```

For `ProfilesController` (no resource to authorize — uses `current_user`):
```ruby
# Skip verify_authorized since these operate on current_user
class ProfilesController < BaseController
  skip_after_action :verify_authorized
  skip_after_action :verify_policy_scoped
  # ... rest unchanged
end
```

For `RegistrationsController` / `SessionsController`:
```ruby
skip_after_action :verify_authorized
skip_after_action :verify_policy_scoped
```

### Step 6: Update `set_*` methods
The `set_*` methods can keep the `.where(user_id:)` scoping — Pundit adds a second layer, not a replacement. This is defense-in-depth.

## Acceptance Criteria
1. `pundit` gem is installed
2. A policy class exists for: Client, ClientGroup, Item, Iva, SellPoint, ClientInvoice, CreditNote, BatchInvoiceProcess
3. Every controller action calls `authorize` on the loaded resource (or `policy_scope` for index)
4. `after_action :verify_authorized` is set in `BaseController` — any action that forgets to authorize raises `Pundit::AuthorizationNotPerformedError` in dev/test
5. Unauthorized access returns `{ "error": { "code": "forbidden", "message": "..." } }` with HTTP 403
6. `ProfilesController`, `RegistrationsController`, and `SessionsController` skip authorization verification
7. `bundle exec rspec` passes

## Risks
- **Scope of change**: Touches every controller. Implement one controller at a time, run specs after each.
- **Performance**: Pundit is plain Ruby objects — negligible overhead.

## Dependencies
- None, but pairs well with HARDEN-013 (multi-tenancy tests)

## Out of Scope
- RBAC (not needed for single-owner model)
- Admin panel / superuser access
- Row-level security (PostgreSQL RLS)
