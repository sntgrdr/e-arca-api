module Constants
  module ArcaIntegration
    module Development
      module FeCompConsultar
        TEMPLATE = <<~XML.freeze
          <?xml version="1.0" encoding="utf-8"?>
          <soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/"
                            xmlns:ar="http://ar.gov.afip.dif.FEV1/">
            <soapenv:Header/>
            <soapenv:Body>
              <ar:FECompConsultar>
                <ar:Auth>
                  <ar:Token><%= token %></ar:Token>
                  <ar:Sign><%= sign %></ar:Sign>
                  <ar:Cuit><%= legal_number %></ar:Cuit>
                </ar:Auth>
                <ar:FeCompConsReq>
                  <ar:CbteTipo><%= afip_code %></ar:CbteTipo>
                  <ar:PtoVta><%= sell_point_number %></ar:PtoVta>
                  <ar:CbteNro><%= invoice_number %></ar:CbteNro>
                </ar:FeCompConsReq>
              </ar:FECompConsultar>
            </soapenv:Body>
          </soapenv:Envelope>
        XML
      end
    end
  end
end
