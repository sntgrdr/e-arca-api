module Lines
  class ApplyAdjustmentsService
    def initialize(invoice:, user:)
      @invoice = invoice
      @user    = user
    end

    def call
      unless @user.adjustments_enabled?
        @invoice.lines.where(line_type: "adjustment").destroy_all
        @invoice.lines.where(line_type: "item").update_all(
          original_price: nil, calculated_price: nil,
          applied_adjustment_id: nil, applied_adjustment_type: nil,
          applied_adjustment_amount: nil
        )
        return
      end

      @invoice.lines.where(line_type: "adjustment").destroy_all

      item_lines = @invoice.lines
                           .where(line_type: "item")
                           .includes(:iva, item: :iva)

      item_lines.each { |line| process_line(line) }
    end

    private

    def process_line(line)
      return unless line.item_id

      adjustments = Adjustments::ResolveService.new(
        user:   @user,
        client: @invoice.client,
        item:   line.item,
        date:   @invoice.date || Date.current
      ).call

      discount  = adjustments[:discount]
      surcharge = adjustments[:surcharge]

      if discount.nil? && surcharge.nil?
        line.update_columns(
          original_price:            nil,
          calculated_price:          nil,
          applied_adjustment_id:     nil,
          applied_adjustment_type:   nil,
          applied_adjustment_amount: nil
        )
        return
      end

      result = Adjustments::CalculateService.new(
        unit_price: line.unit_price,
        discount:   discount,
        surcharge:  surcharge
      ).call

      line.update_columns(
        original_price:            line.unit_price,
        calculated_price:          result[:calculated_price],
        applied_adjustment_id:     (discount || surcharge).id,
        applied_adjustment_type:   discount ? "discount" : "surcharge",
        applied_adjustment_amount: (result[:discount_amount] || result[:surcharge_amount])
      )

      iva_multiplier = 1.0 + (line.iva&.percentage.to_f / 100.0)

      build_adjustment_line(line, discount,  result[:discount_amount],  iva_multiplier) if discount  && result[:discount_amount]
      build_adjustment_line(line, surcharge, result[:surcharge_amount], iva_multiplier, type: :surcharge) if surcharge && result[:surcharge_amount]
    end

    def build_adjustment_line(item_line, adjustment, per_unit_amount, iva_multiplier, type: :discount)
      total_net   = (per_unit_amount * item_line.quantity).round(4)
      total_gross = (total_net * iva_multiplier).round(4)

      @invoice.lines.create!(
        line_type:                 "adjustment",
        description:               line_description(adjustment, item_line.item, type),
        quantity:                  1,
        unit_price:                total_net,
        final_price:               type == :discount ? -total_gross : total_gross,
        iva_id:                    item_line.iva_id,
        user_id:                   @user.id,
        applied_adjustment_id:     adjustment.id,
        applied_adjustment_type:   type.to_s,
        applied_adjustment_amount: total_net
      )
    end

    def line_description(adjustment, item, type)
      label = adjustment.calculation_type == "percentage" ? "#{adjustment.amount.to_i}%" : "$#{adjustment.amount}"
      prefix = type == :discount ? "Descuento" : "Recargo"
      "#{prefix} #{label} - #{item.name}"
    end
  end
end
