# db/seeds.rb — idempotent dev seed
# Run with: bin/rails db:seed

# ── User ─────────────────────────────────────────────────────────────────────
user = User.find_or_create_by!(email: 'dev@example.com') do |u|
  u.password              = 'Secure.pass1'
  u.password_confirmation = 'Secure.pass1'
  u.legal_name            = 'Dev Company SRL'
  u.legal_number          = '20-12345678-9'
  u.name                  = 'Dev User'
  u.tax_condition         = :registered
end

puts "User: #{user.email}"

# ── IVA ──────────────────────────────────────────────────────────────────────
iva = Iva.find_or_create_by!(user: user, percentage: 21) do |i|
  i.name = 'IVA 21%'
end

puts "IVA: #{iva.name}"

# ── Sell Point ────────────────────────────────────────────────────────────────
sell_point = SellPoint.find_or_create_by!(user: user, number: '00001') do |sp|
  sp.name    = 'Punto de Venta Principal'
  sp.default = true
end

puts "Sell point: #{sell_point.number}"

# ── Items ─────────────────────────────────────────────────────────────────────
items_data = [
  { name: 'Servicio de consultoría',  code: 'SRV-001', price: 50_000 },
  { name: 'Licencia de software',     code: 'LIC-001', price: 15_000 },
  { name: 'Soporte técnico mensual',  code: 'SOP-001', price: 25_000 },
]

items = items_data.map do |attrs|
  item = Item.find_or_create_by!(user: user, code: attrs[:code]) do |i|
    i.name  = attrs[:name]
    i.price = attrs[:price]
    i.iva   = iva
  end
  puts "Item: #{item.code} — #{item.name}"
  item
end

# ── Client Groups ─────────────────────────────────────────────────────────────
groups_data = [
  { name: 'Grupo A — Grandes cuentas' },
  { name: 'Grupo B — Pymes' },
  { name: 'Grupo C — Monotributistas' },
]

groups = groups_data.map do |attrs|
  group = ClientGroup.find_or_create_by!(user: user, name: attrs[:name])
  puts "Client group: #{group.name}"
  group
end

group_a, group_b, group_c = groups

# ── Clients (20 total, distributed across groups) ────────────────────────────
# Distribution: 8 in Group A, 7 in Group B, 5 in Group C
clients_data = [
  # Group A — 8 clients
  { legal_name: 'Empresas Grandes SA',       legal_number: '30-10000001-7', tax_condition: :registered,  group: group_a },
  { legal_name: 'Corporación del Norte SRL', legal_number: '30-10000002-5', tax_condition: :registered,  group: group_a },
  { legal_name: 'Holding Sur SA',            legal_number: '30-10000003-3', tax_condition: :registered,  group: group_a },
  { legal_name: 'Inversiones del Este SA',   legal_number: '30-10000004-1', tax_condition: :registered,  group: group_a },
  { legal_name: 'Grupo Andino SRL',          legal_number: '30-10000005-8', tax_condition: :registered,  group: group_a },
  { legal_name: 'Distribuidora Central SA',  legal_number: '30-10000006-6', tax_condition: :registered,  group: group_a },
  { legal_name: 'Importadora Patagonia SA',  legal_number: '30-10000007-4', tax_condition: :registered,  group: group_a },
  { legal_name: 'Constructora Litoral SA',   legal_number: '30-10000008-2', tax_condition: :registered,  group: group_a },

  # Group B — 7 clients
  { legal_name: 'Pyme Soluciones SRL',       legal_number: '30-20000001-6', tax_condition: :registered,  group: group_b },
  { legal_name: 'Comercio Familiar SRL',     legal_number: '30-20000002-4', tax_condition: :registered,  group: group_b },
  { legal_name: 'Servicios Rápidos SRL',     legal_number: '30-20000003-2', tax_condition: :registered,  group: group_b },
  { legal_name: 'Taller del Centro SRL',     legal_number: '30-20000004-9', tax_condition: :registered,  group: group_b },
  { legal_name: 'Logística Express SRL',     legal_number: '30-20000005-7', tax_condition: :registered,  group: group_b },
  { legal_name: 'Consultora Regional SRL',   legal_number: '30-20000006-5', tax_condition: :registered,  group: group_b },
  { legal_name: 'Agencia Digital SRL',       legal_number: '30-20000007-3', tax_condition: :registered,  group: group_b },

  # Group C — 5 clients
  { legal_name: 'García Juan Carlos',        legal_number: '20-30000001-5', tax_condition: :self_employed, group: group_c },
  { legal_name: 'López María Fernanda',      legal_number: '27-30000002-3', tax_condition: :self_employed, group: group_c },
  { legal_name: 'Martínez Roberto',          legal_number: '20-30000003-1', tax_condition: :self_employed, group: group_c },
  { legal_name: 'Rodríguez Ana Paula',       legal_number: '27-30000004-8', tax_condition: :self_employed, group: group_c },
  { legal_name: 'Pérez Diego Hernán',        legal_number: '20-30000005-6', tax_condition: :self_employed, group: group_c },
]

clients_data.each do |attrs|
  client = Client.find_or_create_by!(user: user, legal_number: attrs[:legal_number]) do |c|
    c.legal_name    = attrs[:legal_name]
    c.tax_condition = attrs[:tax_condition]
    c.client_group  = attrs[:group]
    c.iva           = iva
    c.active        = true
  end
  puts "Client: #{client.legal_name} → #{client.client_group.name}"
end

puts "\nDone! #{Client.where(user: user).count} clients, #{Item.where(user: user).count} items, #{ClientGroup.where(user: user).count} groups."
