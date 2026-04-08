module Invoices
  module Development
    class GenerateLoginTicketService
      def self.generate(service)
        now = Time.now.utc

        <<~XML
          <loginTicketRequest version="1.0">
            <header>
              <uniqueId>1706418170</uniqueId>
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
