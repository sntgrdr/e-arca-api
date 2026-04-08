module Constants
  class Arca
    TAX_CONDITIONS = {
      final_client: 5,
      registered: 1,
      exempt: 4,
      self_employed: 6
    }.freeze

    INVOICE_TYPES = [
      'A',
      'B',
      'C',
      'E'
    ].freeze

    IVA_CODES = {
      0.0   => '0003',
      10.5  => '0004',
      21.0  => '0005',
      27.0  => '0006',
      5.0   => '0008',
      2.5   => '0009'
    }.freeze

    ARCA_TAX_CONDITIONS = {
      'registered' => 1,
      'final_client' => 5,
      'exempt' => 4,
      'self_employed' => 6
    }.freeze

    def self.afip_code_for_percentage(percentage)
      IVA_CODES[percentage.to_f] || '0005'
    end
  end
end
