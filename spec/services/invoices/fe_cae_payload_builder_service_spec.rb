require 'rails_helper'

RSpec.describe Invoices::FeCaePayloadBuilderService, type: :service do
  let(:user) { create(:user, legal_number: '20-12345678-9') }
  let(:client) { create(:client, user: user, tax_condition: :final_client) }
  let(:sell_point) { create(:sell_point, user: user, number: '1') }
  let(:iva) { create(:iva, user: user, percentage: 21.0) }
  let(:item) { create(:item, user: user, iva: iva) }

  let(:token) { 'TOKEN_ABC123' }
  let(:sign) { 'SIGN_XYZ789' }

  let(:invoice) do
    inv = create(:client_invoice,
                 user: user,
                 client: client,
                 sell_point: sell_point,
                 invoice_type: 'C',
                 number: '5',
                 date: Date.new(2024, 3, 15),
                 period: Date.new(2024, 3, 1))
    create(:line, lineable: inv, user: user, item: item, iva: iva,
           description: 'Servicio de consultoria', quantity: 1,
           unit_price: 1000.0, final_price: 1000.0)
    inv
  end

  subject(:service) { described_class.new(invoice: invoice, token: token, sign: sign) }

  # Force non-production environment to use the development template
  before do
    allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('test'))
  end

  describe '#call' do
    subject(:xml) { service.call }

    it 'returns a non-empty String' do
      expect(xml).to be_a(String)
      expect(xml).not_to be_empty
    end

    it 'produces well-formed XML' do
      doc = Nokogiri::XML(xml)
      expect(doc.errors).to be_empty
    end

    it 'includes the FECAESolicitar SOAP action' do
      expect(xml).to include('FECAESolicitar')
    end

    describe 'Auth section' do
      it 'includes the token' do
        expect(xml).to include(token)
      end

      it 'includes the sign' do
        expect(xml).to include(sign)
      end

      it 'includes the CUIT (legal_number without dashes)' do
        doc = Nokogiri::XML(xml)
        doc.remove_namespaces!
        cuit_node = doc.at_xpath('//Auth/Cuit')
        expect(cuit_node&.content).to eq(user.legal_number)
      end
    end

    describe 'FeCabReq section (invoice header)' do
      let(:doc) do
        d = Nokogiri::XML(xml)
        d.remove_namespaces!
        d
      end

      it 'sets CbteTipo to afip_code of the invoice' do
        cbe_tipo = doc.at_xpath('//FeCabReq/CbteTipo')
        expect(cbe_tipo&.content).to eq(invoice.afip_code.to_s)
      end

      it 'sets PtoVta to the sell point number' do
        pto_vta = doc.at_xpath('//FeCabReq/PtoVta')
        expect(pto_vta&.content).to eq(sell_point.number.to_s)
      end

      it 'sets CantReg to 1' do
        cant_reg = doc.at_xpath('//FeCabReq/CantReg')
        expect(cant_reg&.content).to eq('1')
      end
    end

    describe 'FECAEDetRequest section (invoice detail)' do
      let(:doc) do
        d = Nokogiri::XML(xml)
        d.remove_namespaces!
        d
      end

      it 'includes DocTipo' do
        expect(doc.at_xpath('//FECAEDetRequest/DocTipo')).not_to be_nil
      end

      it 'includes DocNro' do
        expect(doc.at_xpath('//FECAEDetRequest/DocNro')).not_to be_nil
      end

      it 'includes CbteDesde' do
        cbte_desde = doc.at_xpath('//FECAEDetRequest/CbteDesde')
        expect(cbte_desde&.content).to eq(invoice.number_from.to_s)
      end

      it 'includes CbteHasta' do
        cbte_hasta = doc.at_xpath('//FECAEDetRequest/CbteHasta')
        expect(cbte_hasta&.content).to eq(invoice.number_to.to_s)
      end

      it 'includes CbteFch in YYYYMMDD format' do
        cbte_fch = doc.at_xpath('//FECAEDetRequest/CbteFch')
        expect(cbte_fch&.content).to eq('20240315')
      end

      it 'includes ImpTotal' do
        imp_total = doc.at_xpath('//FECAEDetRequest/ImpTotal')
        expect(imp_total).not_to be_nil
        expect(imp_total.content.to_f).to be > 0
      end

      it 'includes ImpNeto' do
        expect(doc.at_xpath('//FECAEDetRequest/ImpNeto')).not_to be_nil
      end

      it 'includes ImpIVA' do
        expect(doc.at_xpath('//FECAEDetRequest/ImpIVA')).not_to be_nil
      end

      it 'includes MonId set to PES' do
        mon_id = doc.at_xpath('//FECAEDetRequest/MonId')
        expect(mon_id&.content).to eq('PES')
      end

      it 'includes MonCotiz set to 1.00' do
        mon_cotiz = doc.at_xpath('//FECAEDetRequest/MonCotiz')
        expect(mon_cotiz&.content).to eq('1.00')
      end

      it 'includes CondicionIVAReceptorId' do
        expect(doc.at_xpath('//FECAEDetRequest/CondicionIVAReceptorId')).not_to be_nil
      end
    end

    context 'for a type C invoice (monotributista)' do
      it 'sets afip_code to 11' do
        expect(invoice.afip_code).to eq('11')
      end

      it 'does not include an Iva section (type C is exempt from itemized IVA)' do
        doc = Nokogiri::XML(xml)
        doc.remove_namespaces!
        # afip_code 11 should skip the Iva block per the template condition
        expect(doc.at_xpath('//FECAEDetRequest/Iva')).to be_nil
      end

      it 'sets ImpNeto equal to the total (monotributista invoices have no split)' do
        doc = Nokogiri::XML(xml)
        doc.remove_namespaces!
        imp_neto = doc.at_xpath('//FECAEDetRequest/ImpNeto')&.content.to_f
        imp_total = doc.at_xpath('//FECAEDetRequest/ImpTotal')&.content.to_f
        expect(imp_neto).to eq(imp_total)
      end
    end

    context 'for a type A invoice (responsable inscripto)' do
      let(:client_a) { create(:client, user: user, tax_condition: :registered) }
      let(:invoice) do
        inv = create(:client_invoice,
                     user: user,
                     client: client_a,
                     sell_point: sell_point,
                     invoice_type: 'A',
                     number: '3',
                     date: Date.new(2024, 3, 15),
                     period: Date.new(2024, 3, 1))
        create(:line, lineable: inv, user: user, item: item, iva: iva,
               description: 'Consultoria', quantity: 2,
               unit_price: 500.0, final_price: 605.0)
        inv
      end

      it 'sets afip_code to 1' do
        expect(invoice.afip_code).to eq('1')
      end

      it 'produces well-formed XML' do
        doc = Nokogiri::XML(xml)
        expect(doc.errors).to be_empty
      end

      it 'includes an Iva section with IVA breakdown' do
        doc = Nokogiri::XML(xml)
        doc.remove_namespaces!
        # afip_code 1 should include IVA items
        iva_section = doc.at_xpath('//FECAEDetRequest/Iva')
        expect(iva_section).not_to be_nil
      end

      it 'includes AlicIva entries with Id, BaseImp and Importe' do
        doc = Nokogiri::XML(xml)
        doc.remove_namespaces!
        alic_iva = doc.at_xpath('//Iva/AlicIva')
        expect(alic_iva).not_to be_nil
        expect(alic_iva.at_xpath('Id')).not_to be_nil
        expect(alic_iva.at_xpath('BaseImp')).not_to be_nil
        expect(alic_iva.at_xpath('Importe')).not_to be_nil
      end
    end

    context 'for a type B invoice' do
      let(:invoice) do
        inv = create(:client_invoice,
                     user: user,
                     client: client,
                     sell_point: sell_point,
                     invoice_type: 'B',
                     number: '7',
                     date: Date.new(2024, 3, 15),
                     period: Date.new(2024, 3, 1))
        create(:line, lineable: inv, user: user, item: item, iva: iva,
               description: 'Servicio B', quantity: 1,
               unit_price: 800.0, final_price: 968.0)
        inv
      end

      it 'sets afip_code to 6' do
        expect(invoice.afip_code).to eq('6')
      end

      it 'produces well-formed XML' do
        doc = Nokogiri::XML(xml)
        expect(doc.errors).to be_empty
      end
    end

    context 'IVA totals for a 21% IVA line' do
      let(:invoice) do
        inv = create(:client_invoice,
                     user: user,
                     client: create(:client, user: user, tax_condition: :registered),
                     sell_point: sell_point,
                     invoice_type: 'A',
                     number: '10',
                     date: Date.new(2024, 4, 1),
                     period: Date.new(2024, 4, 1))
        create(:line, lineable: inv, user: user, item: item, iva: iva,
               description: 'Item con IVA 21%', quantity: 1,
               unit_price: 1000.0, final_price: 1210.0)
        inv
      end

      it 'sets ImpIVA to 21% of the net amount' do
        doc = Nokogiri::XML(xml)
        doc.remove_namespaces!
        imp_iva = doc.at_xpath('//FECAEDetRequest/ImpIVA')&.content.to_f
        expect(imp_iva).to eq(210.0)
      end

      it 'sets AlicIva BaseImp to the net unit price' do
        doc = Nokogiri::XML(xml)
        doc.remove_namespaces!
        base_imp = doc.at_xpath('//Iva/AlicIva/BaseImp')&.content.to_f
        expect(base_imp).to eq(1000.0)
      end

      it 'sets AlicIva Importe to the IVA amount' do
        doc = Nokogiri::XML(xml)
        doc.remove_namespaces!
        importe = doc.at_xpath('//Iva/AlicIva/Importe')&.content.to_f
        expect(importe).to eq(210.0)
      end
    end
  end
end
