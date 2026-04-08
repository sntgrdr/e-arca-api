module Constants
  module ArcaIntegration
    module Production
      class FeCaeSolicitar
        TEMPLATE = <<~XML
          <?xml version="1.0" encoding="UTF-8"?>
          <soapenv:Envelope
            xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/"
            xmlns:ar="http://ar.gov.afip.dif.FEV1/">

            <soapenv:Header/>

            <soapenv:Body>
              <ar:FECAESolicitar>
                <ar:Auth>
                  <ar:Token><%= token %></ar:Token>
                  <ar:Sign><%= sign %></ar:Sign>
                  <ar:Cuit><%= legal_number %></ar:Cuit>
                </ar:Auth>

                <ar:FeCAEReq>
                  <ar:FeCabReq>
                    <ar:CantReg><%= register %></ar:CantReg>
                    <ar:PtoVta><%= sell_point %></ar:PtoVta>
                    <ar:CbteTipo><%= afip_code %></ar:CbteTipo>
                  </ar:FeCabReq>

                  <ar:FeDetReq>
                    <ar:FECAEDetRequest>
                      <ar:Concepto>2</ar:Concepto>

                      <ar:DocTipo><%= document_type %></ar:DocTipo>
                      <ar:DocNro><%= document_number %></ar:DocNro>

                      <ar:CbteDesde><%= number_from %></ar:CbteDesde>
                      <ar:CbteHasta><%= number_to %></ar:CbteHasta>
                      <ar:CbteFch><%= date %></ar:CbteFch>

                      <ar:ImpTotal><%= invoice_total %></ar:ImpTotal>
                      <ar:ImpTotConc><%= non_tax_total %></ar:ImpTotConc>
                      <ar:ImpNeto><%= invoice_net_total %></ar:ImpNeto>
                      <ar:ImpOpEx><%= invoice_exempt_total %></ar:ImpOpEx>
                      <ar:ImpTrib><%= invoice_tribute_total %></ar:ImpTrib>
                      <ar:ImpIVA><%= invoice_iva_total %></ar:ImpIVA>

                      <ar:FchServDesde><%= service_date_from %></ar:FchServDesde>
                      <ar:FchServHasta><%= service_date_to %></ar:FchServHasta>
                      <ar:FchVtoPago><%= invoice_due_date %></ar:FchVtoPago>

                      <ar:MonId><%= money %></ar:MonId>
                      <ar:MonCotiz><%= money_value %></ar:MonCotiz>

                      <ar:CondicionIVAReceptorId>
                        <%= client_tax_condition %>
                      </ar:CondicionIVAReceptorId>
                      <% if has_associated_cbte? %>
                        <ar:CbtesAsoc>
                          <ar:CbteAsoc>
                            <ar:Tipo><%= associated_cbte_tipo %></ar:Tipo>
                            <ar:PtoVta><%= associated_cbte_punto_vta %></ar:PtoVta>
                            <ar:Nro><%= associated_cbte_numero %></ar:Nro>
                          </ar:CbteAsoc>
                        </ar:CbtesAsoc>
                      <% end %>

                      <% unless ["11", "12", "13"].include?(afip_code.to_s) %>
                        <ar:Iva>
                          <% iva_items.each do |iva| %>
                            <ar:AlicIva>
                              <ar:Id><%= iva[:iva_id] %></ar:Id>
                              <ar:BaseImp><%= iva[:iva_base_imp] %></ar:BaseImp>
                              <ar:Importe><%= iva[:iva_importe] %></ar:Importe>
                            </ar:AlicIva>
                          <% end %>
                        </ar:Iva>
                      <% end %>

                    </ar:FECAEDetRequest>
                  </ar:FeDetReq>
                </ar:FeCAEReq>
              </ar:FECAESolicitar>
            </soapenv:Body>
          </soapenv:Envelope>
        XML
      end
    end
  end
end
