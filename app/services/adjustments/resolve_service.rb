module Adjustments
  class ResolveService
    SCOPE_PRIORITY  = { 'item' => 3, 'item_group' => 2, 'global' => 1 }.freeze
    TARGET_PRIORITY = { 'Client' => 2, 'ClientGroup' => 1 }.freeze

    def initialize(user:, client:, item:, date: Date.current)
      @user   = user
      @client = client
      @item   = item
      @date   = date
    end

    def call
      candidates = fetch_candidates
      {
        discount:  best(candidates.select { |a| a.adjustment_type == 'discount' }),
        surcharge: best(candidates.select { |a| a.adjustment_type == 'surcharge' })
      }
    end

    private

    def fetch_candidates
      target_conditions = []
      target_values     = []

      target_conditions << "(target_type = ? AND target_id = ?)"
      target_values.concat(['Client', @client.id])

      if @client.client_group_id
        target_conditions << "(target_type = ? AND target_id = ?)"
        target_values.concat(['ClientGroup', @client.client_group_id])
      end

      Adjustment.kept
                .active
                .valid_on(@date)
                .where(user_id: @user.id)
                .where(target_conditions.join(" OR "), *target_values)
                .includes(:adjustment_applicables)
    end

    def best(adjustments)
      adjustments.filter_map { |a|
        priority = score(a)
        next if priority.nil?
        [a, priority]
      }.max_by { |_a, s| s }&.first
    end

    def score(adjustment)
      target_priority = TARGET_PRIORITY[adjustment.target_type] || 0
      scope_priority  = applicable_scope_priority(adjustment)
      return nil if scope_priority.nil?

      [target_priority, scope_priority, adjustment.id]
    end

    def applicable_scope_priority(adjustment)
      applicables = adjustment.adjustment_applicables
      return SCOPE_PRIORITY['global'] if applicables.empty?

      applicables.each do |ap|
        return SCOPE_PRIORITY['item']       if ap.applicable_type == 'Item'      && ap.applicable_id == @item.id
        return SCOPE_PRIORITY['item_group'] if ap.applicable_type == 'ItemGroup' && ap.applicable_id == @item.item_group_id
      end

      nil
    end
  end
end
