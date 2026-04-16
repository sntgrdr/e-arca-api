class ClientsSearchQuery
  def self.call(q:, current_user:, limit: 25, client_group_id: nil)
    new(q: q, current_user: current_user, limit: limit, client_group_id: client_group_id).call
  end

  def initialize(q:, current_user:, limit: 25, client_group_id: nil)
    @q               = q
    @current_user    = current_user
    @limit           = limit
    @client_group_id = client_group_id
  end

  def call
    scope = Client.all_my_clients(@current_user.id).active.order(:legal_name).limit(@limit)
    scope = scope.where(client_group_id: @client_group_id) if @client_group_id.present?
    return scope if @q.blank?

    term = "%#{Client.sanitize_sql_like(@q)}%"
    scope.where("legal_name ILIKE :q OR name ILIKE :q", q: term)
  end
end
