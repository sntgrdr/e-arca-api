module CreditNotes
  class BuildFromInvoiceService
    def self.call(user:, client_invoice_id:, date:, period: nil, lines_attributes: nil, details: nil, number: nil)
      new(
        user:              user,
        client_invoice_id: client_invoice_id,
        lines_attributes:  lines_attributes,
        date:              date,
        period:            period,
        details:           details,
        number:            number
      ).call
    end

    def initialize(user:, client_invoice_id:, date:, period: nil, lines_attributes: nil, details: nil, number: nil)
      @user              = user
      @client_invoice_id = client_invoice_id
      @lines_attributes  = lines_attributes
      @date              = date
      @period            = period
      @details           = details
      @number            = number
    end

    def call
      invoice = ClientInvoice
        .kept
        .includes({ lines: :iva }, credit_notes: :lines)
        .where(user_id: @user.id)
        .find(@client_invoice_id)

      invoice_type  = invoice.invoice_type
      sell_point    = invoice.sell_point
      number        = @number || CreditNote.current_number(@user.id, sell_point.id, invoice_type)
      period        = @period || invoice.period&.to_s
      lines         = resolved_lines(invoice)
      total_price   = lines.sum { |l| BigDecimal(l[:final_price].to_s) }

      credit_note = CreditNote.new(
        user_id:           @user.id,
        client_id:         invoice.client_id,
        sell_point_id:     sell_point.id,
        client_invoice_id: invoice.id,
        invoice_type:      invoice_type,
        number:            number,
        date:              @date,
        period:            period,
        total_price:       total_price,
        details:           @details,
        lines_attributes:  lines
      )

      preload_iva_on_lines(credit_note, invoice)
      credit_note
    end

    private

    def preload_iva_on_lines(credit_note, invoice)
      iva_by_id = invoice.lines.each_with_object({}) do |line, hash|
        hash[line.iva_id] = line.iva if line.iva_id
      end

      credit_note.lines.each do |line|
        line.iva = iva_by_id[line.iva_id] if line.iva_id
      end
    end

    def resolved_lines(invoice)
      if @lines_attributes.present?
        @lines_attributes.map { |line| line.except(:id).merge(user_id: @user.id) }
      else
        remaining_lines(invoice)
      end
    end

    def remaining_lines(invoice)
      # Track credited amount per item_id using BigDecimal for exact arithmetic.
      credited_per_item = Hash.new(BigDecimal("0"))
      invoice.credit_notes.each do |cn|
        cn.lines.each do |line|
          credited_per_item[line.item_id] += BigDecimal(line.final_price.to_s)
        end
      end

      invoice.lines.filter_map do |line|
        invoice_final = BigDecimal(line.final_price.to_s)
        credited      = credited_per_item[line.item_id]
        remaining     = invoice_final - credited
        next if remaining <= 0

        qty              = BigDecimal(line.quantity.to_s)
        remaining_unit   = qty > 0 ? (remaining / qty).round(4, BigDecimal::ROUND_HALF_UP) : BigDecimal(line.unit_price.to_s)

        {
          item_id:     line.item_id,
          description: line.description,
          quantity:    line.quantity,
          unit_price:  remaining_unit,
          final_price: remaining.round(4, BigDecimal::ROUND_HALF_UP),
          iva_id:      line.iva_id,
          user_id:     @user.id
        }
      end
    end
  end
end
