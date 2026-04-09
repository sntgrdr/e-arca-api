module Invoices
  module Production
    class GenerateLoginTicketService
      def self.generate(service)
        now = Time.zone.now.utc

        <<~XML
          <loginTicketRequest version="1.0">
            <header>
              <uniqueId>#{now.to_i}</uniqueId>
              <generationTime>#{(now - 300).iso8601}</generationTime>
              <expirationTime>#{(now + 300).iso8601}</expirationTime>
            </header>
            <service>#{service}</service>
          </loginTicketRequest>
        XML
      end
    end
  end
end
