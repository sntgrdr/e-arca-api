module Constants
  class FeCompUltimoAutorizado
    TEMPLATE = <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <soapenv:Envelope
        xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/"
        xmlns:ar="http://ar.gov.afip.dif.FEV1/">

        <soapenv:Header/>

        <soapenv:Body>
          <ar:FECompUltimoAutorizado>
            <ar:Auth>
              <ar:Token><%= token %></ar:Token>
              <ar:Sign><%= sign %></ar:Sign>
              <ar:Cuit><%= legal_number %></ar:Cuit>
            </ar:Auth>

            <ar:PtoVta><%= sell_point_number %></ar:PtoVta>
            <ar:CbteTipo><%= afip_code %></ar:CbteTipo>
          </ar:FECompUltimoAutorizado>
        </soapenv:Body>

      </soapenv:Envelope>
    XML
  end
end
