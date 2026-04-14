FactoryBot.define do
  factory :client_invoice do
    association :user
    association :client
    association :sell_point
    sequence(:number) { |n| n.to_s }
    date { Date.current }
    period { Date.current }
    invoice_type { 'C' }
    total_price { 1000.0 }
    batch_invoice_process_id { nil }

    after(:build) do |invoice|
      if invoice.lines.empty?
        iva  = create(:iva, user: invoice.user)
        item = create(:item, user: invoice.user, iva: iva)
        invoice.lines.build(
          user: invoice.user, item: item, iva: iva,
          description: 'Servicio mensual', quantity: 1,
          unit_price: 1000.0, final_price: 1000.0
        )
      end
    end

    trait :with_cae do
      cae { '12345678901234' }
      cae_expiration { 10.days.from_now.to_date }
      afip_invoice_number { '1' }
      afip_result { 'A' }
      afip_authorized_at { Time.current }
      afip_status { :authorized }
    end

    trait :with_lines do
      after(:build) do |invoice|
        iva  = create(:iva, user: invoice.user)
        item = create(:item, user: invoice.user, iva: iva)
        invoice.lines.build(
          user: invoice.user, item: item, iva: iva,
          description: 'Servicio mensual', quantity: 1,
          unit_price: 1000.0, final_price: 1000.0
        )
      end
    end
  end

  factory :credit_note do
    association :client_invoice, factory: [ :client_invoice, :with_cae ]
    sequence(:number) { |n| n.to_s }
    date { Date.current }
    total_price { 500.0 }

    after(:build) do |credit_note|
      # Keep credit_note consistent with its client_invoice
      if credit_note.client_invoice
        credit_note.user       ||= credit_note.client_invoice.user
        credit_note.client     ||= credit_note.client_invoice.client
        credit_note.sell_point ||= credit_note.client_invoice.sell_point
        credit_note.invoice_type ||= credit_note.client_invoice.invoice_type
        credit_note.period       ||= credit_note.client_invoice.period
      end

      # Ensure at least one line — reuse item from client_invoice when possible
      if credit_note.lines.empty? && credit_note.user
        invoice_line = credit_note.client_invoice&.lines&.first
        if invoice_line
          half_qty   = (invoice_line.quantity.to_f / 2).round(4)
          half_final = (invoice_line.final_price.to_f / 2).round(4)
          credit_note.lines.build(
            user: credit_note.user,
            item: invoice_line.item,
            iva: invoice_line.iva,
            description: invoice_line.description,
            quantity: half_qty,
            unit_price: invoice_line.unit_price,
            final_price: half_final
          )
          credit_note.total_price ||= half_final
        else
          iva  = create(:iva, user: credit_note.user)
          item = create(:item, user: credit_note.user, iva: iva)
          credit_note.lines.build(
            user: credit_note.user, item: item, iva: iva,
            description: 'Servicio', quantity: 1,
            unit_price: 500.0, final_price: 500.0
          )
        end
      end
    end

    trait :with_cae do
      cae { '12345678901234' }
      cae_expiration { 10.days.from_now.to_date }
      afip_invoice_number { '1' }
      afip_result { 'A' }
      afip_authorized_at { Time.current }
      afip_status { :authorized }
    end

    trait :with_lines do
      after(:build) do |credit_note|
        iva  = create(:iva, user: credit_note.user)
        item = create(:item, user: credit_note.user, iva: iva)
        credit_note.lines.build(
          user: credit_note.user, item: item, iva: iva,
          description: 'Servicio', quantity: 1,
          unit_price: 500.0, final_price: 500.0
        )
      end
    end
  end
end
