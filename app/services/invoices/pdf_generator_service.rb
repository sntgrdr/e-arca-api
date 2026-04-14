require "prawn"
require "prawn/table"
require "rqrcode"

module Invoices
  class PdfGeneratorService
    FONT_SIZE_SMALL = 8
    FONT_SIZE_NORMAL = 10
    FONT_SIZE_LARGE = 14
    FONT_SIZE_LETTER = 28
    COLOR_DARK = "4A4E69"

    def initialize(invoice:)
      @invoice = invoice
    end

    def call
      raise ArgumentError, "El comprobante debe tener CAE para generar el PDF" unless @invoice.cae.present?

      pdf = Prawn::Document.new(page_size: "A4", margin: 30)
      render_header(pdf)
      render_client_section(pdf)
      render_lines_table(pdf)
      render_total(pdf)
      render_qr_code(pdf)
      pdf.render
    end

    private

    def render_header(pdf)
      top = pdf.cursor

      # Invoice type letter box — centered
      letter_box_size = 40
      letter_x = (pdf.bounds.width / 2) - (letter_box_size / 2)
      pdf.bounding_box([ letter_x, top ], width: letter_box_size, height: letter_box_size) do
        pdf.stroke_bounds
        pdf.move_down 6
        pdf.text @invoice.invoice_type, size: FONT_SIZE_LETTER, style: :bold, align: :center
      end

      # Left side — issuer info
      pdf.bounding_box([ 0, top - 50 ], width: pdf.bounds.width / 2 - 20) do
        pdf.text @invoice.user.legal_name, size: FONT_SIZE_LARGE, style: :bold
        pdf.move_down 4
        pdf.text "CUIT: #{@invoice.user.legal_number}", size: FONT_SIZE_NORMAL
        if @invoice.user.address.present?
          pdf.text @invoice.user.address, size: FONT_SIZE_NORMAL
        end
        if @invoice.user.tax_condition.present?
          pdf.text "Cond. IVA: #{I18n.t("tax_conditions.#{@invoice.user.tax_condition}")}", size: FONT_SIZE_NORMAL
        end
        if @invoice.user.activity_start.present?
          pdf.text "Inicio de actividad: #{@invoice.user.activity_start.strftime('%d/%m/%Y')}", size: FONT_SIZE_NORMAL
        end
      end

      # Right side — invoice metadata
      right_x = pdf.bounds.width / 2 + 20
      pdf.bounding_box([ right_x, top - 50 ], width: pdf.bounds.width / 2 - 20) do
        pdf.text "#{document_label} #{@invoice.invoice_type}", size: FONT_SIZE_LARGE, style: :bold, align: :right
        pdf.move_down 4
        pdf.text "N°: #{@invoice.sell_point.number.to_s.rjust(4, '0')}-#{@invoice.number.to_s.rjust(8, '0')}", size: FONT_SIZE_NORMAL, align: :right
        pdf.text "Fecha: #{@invoice.date.strftime('%d/%m/%Y')}", size: FONT_SIZE_NORMAL, align: :right
        pdf.text "Período: #{@invoice.period.strftime('%m/%Y')}", size: FONT_SIZE_NORMAL, align: :right
        pdf.move_down 4
        pdf.text "CAE: #{@invoice.cae}", size: FONT_SIZE_NORMAL, align: :right
        pdf.text "Vto. CAE: #{@invoice.cae_expiration&.strftime('%d/%m/%Y')}", size: FONT_SIZE_NORMAL, align: :right
      end

      pdf.move_down 10
      pdf.stroke_horizontal_rule
      pdf.move_down 10
    end

    def render_client_section(pdf)
      pdf.text "Datos del cliente", size: FONT_SIZE_NORMAL, style: :bold
      pdf.move_down 4
      pdf.text @invoice.client.legal_name, size: FONT_SIZE_NORMAL
      pdf.text "CUIT: #{@invoice.client.legal_number}", size: FONT_SIZE_NORMAL
      if @invoice.client.tax_condition.present?
        pdf.text "Cond. IVA: #{I18n.t("tax_conditions.#{@invoice.client.tax_condition}")}", size: FONT_SIZE_NORMAL
      end

      pdf.move_down 10
      pdf.stroke_horizontal_rule
      pdf.move_down 10
    end

    def render_lines_table(pdf)
      header = [
        { content: "Cantidad", font_style: :bold },
        { content: "Descripción", font_style: :bold },
        { content: "Precio unitario", font_style: :bold },
        { content: "IVA %", font_style: :bold },
        { content: "Precio final", font_style: :bold }
      ]

      rows = @invoice.lines.includes(:iva, item: :iva).map do |line|
        iva_percentage = line.iva&.percentage || line.item&.iva&.percentage
        [
          format_number(line.quantity),
          line.description,
          format_currency(line.unit_price),
          iva_percentage.present? ? "#{iva_percentage}%" : "-",
          format_currency(line.final_price)
        ]
      end

      pdf.table([ header ] + rows, width: pdf.bounds.width) do |t|
        t.row(0).background_color = COLOR_DARK
        t.row(0).text_color = "FFFFFF"
        t.cells.size = FONT_SIZE_SMALL
        t.cells.padding = [ 6, 8 ]
        t.columns(0).align = :center
        t.columns(2..4).align = :right
        t.cells.borders = [ :bottom ]
        t.cells.border_color = "CCCCCC"
        t.row(0).borders = [ :bottom ]
        t.row(0).border_color = COLOR_DARK
      end
    end

    def render_total(pdf)
      pdf.move_down 10
      pdf.text "Total: #{format_currency(@invoice.total_price)}", size: FONT_SIZE_LARGE, style: :bold, align: :right
      pdf.move_down 20
    end

    def render_qr_code(pdf)
      url = build_afip_qr_url
      qr = RQRCode::QRCode.new(url)
      png = qr.as_png(size: 200, border_modules: 1)

      pdf.image StringIO.new(png.to_s), width: 120, position: :left
      pdf.move_down 4
      pdf.text "Comprobante autorizado por ARCA", size: FONT_SIZE_SMALL, color: "666666"
    end

    def build_afip_qr_url
      data = {
        ver: 1,
        fecha: @invoice.date.iso8601,
        cuit: @invoice.user.legal_number.gsub("-", "").to_i,
        ptoVta: @invoice.sell_point.number.to_i,
        tipoCmp: @invoice.afip_code.to_i,
        nroCmp: @invoice.number.to_i,
        importe: @invoice.total_price.to_f,
        moneda: "PES",
        ctz: 1,
        tipoCodAut: "E",
        codAut: @invoice.cae.to_i
      }

      unless @invoice.invoice_type == "C"
        data[:tipoDocRec] = 80
        data[:nroDocRec] = @invoice.client.legal_number.gsub("-", "").to_i
      end

      encoded = Base64.strict_encode64(data.to_json)
      "https://www.afip.gob.ar/fe/qr/?p=#{encoded}"
    end

    def document_label
      @invoice.is_a?(CreditNote) ? "Nota de Crédito" : "Factura"
    end

    def format_currency(amount)
      return "$0,00" unless amount
      "$#{format('%.2f', amount).gsub('.', ',')}"
    end

    def format_number(num)
      return "0" unless num
      num.to_i == num ? num.to_i.to_s : format("%.2f", num)
    end
  end
end
