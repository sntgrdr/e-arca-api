module Reportable
  extend ActiveSupport::Concern

  def legal_number
    user.legal_number
  end

  def register
    1
  end

  def sell_point_number
    self[:sell_point]&.number || self.sell_point_id
  end

  def afip_code
    code = "00"
    if self.invoice_type == "A" || self.invoice_type == "EA"
      code = "2"
    elsif self.invoice_type == "B" || self.invoice_type == "EB"
      code = "7"
    elsif self.invoice_type == "C" || self.invoice_type == "EC"
      code = "12"
    elsif self.invoice_type == "EE"
      code = "19"
    end
    code
  end

  def document_type
    99
  end

  def document_number
    0
  end

  def number_from
    number
  end

  def number_to
    number
  end

  def date_to_s
    date.strftime("%Y%m%d")
  end

  def invoice_total
    format("%.2f", gross_total)
  end

  def non_tax_total
    "0.00"
  end

  def invoice_net_total
    monotributista? ? format("%.2f", gross_total) : format("%.2f", net_amount)
  end

  def invoice_exempt_total
    format("%.2f", exempt_amount)
  end

  def invoice_tribute_total
    format("%.2f", tribute_amount)
  end

  def invoice_iva_total
    monotributista? ? "0.00" : format("%.2f", iva_amount)
  end

  def service_date_from
    service? ? service_range.first.strftime("%Y%m%d") : ""
  end

  def service_date_to
    service? ? service_range.last.strftime("%Y%m%d") : ""
  end

  def invoice_due_date
    (service? ? service_range.last : self[:date]).strftime("%Y%m%d")
  end

  def money
    "PES"
  end

  def money_value
    "1.00"
  end

  def client_tax_condition
    ::Constants::Arca::ARCA_TAX_CONDITIONS[client&.tax_condition] || 5
  end

  def iva_items
    return [] if afip_code == "11"

    lines
      .select { |l| l.iva.present? && l.iva.percentage.to_f.positive? }
      .group_by { |l| Constants::Arca.afip_code_for_percentage(l.iva.percentage) }
      .map do |iva_code, grouped_lines|
        base = grouped_lines.sum(&:unit_price)
        rate = grouped_lines.first.iva.percentage.to_f
        amount = (base * rate / 100.0).round(2)

        {
          iva_id: iva_code,
          iva_base_imp: format("%.2f", base),
          iva_importe:  format("%.2f", amount)
        }
      end
  end

  def concept
    2
  end

  def has_associated_cbte?
    false
  end

  private

  def service?
    true
  end

  def service_range
    date.beginning_of_month..date.end_of_month
  end

  def monotributista?
    invoice_type == "C"
  end

  def gross_total
    if monotributista?
      lines.sum(&:final_price)
    else
      net_amount + iva_amount + tribute_amount + exempt_amount
    end
  end

  def net_amount
    lines.sum(&:unit_price)
  end

  def iva_amount
    lines.sum { |l| l.unit_price * (l.iva&.percentage || 0) / 100.0 }
  end

  def tribute_amount
    0
  end

  def exempt_amount
    0
  end
end
