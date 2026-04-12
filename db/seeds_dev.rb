# db/seeds.rb — idempotent dev seed
# Run with: bin/rails db:seed

# ── User ─────────────────────────────────────────────────────────────────────
user = User.find_or_create_by!(email: 'dev@example.com') do |u|
  u.password              = 'Secure.pass1'
  u.password_confirmation = 'Secure.pass1'
  u.legal_name            = 'Dev Company SRL'
  u.legal_number          = '20123456789'
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
  { name: 'Soporte técnico mensual',  code: 'SOP-001', price: 25_000 }
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
  { name: 'Grupo C — Monotributistas' }
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
  { legal_name: 'Empresas Grandes SA',       legal_number: '30100000017', tax_condition: :registered,    group: group_a },
  { legal_name: 'Corporación del Norte SRL', legal_number: '30100000025', tax_condition: :registered,    group: group_a },
  { legal_name: 'Holding Sur SA',            legal_number: '30100000033', tax_condition: :registered,    group: group_a },
  { legal_name: 'Inversiones del Este SA',   legal_number: '30100000041', tax_condition: :registered,    group: group_a },
  { legal_name: 'Grupo Andino SRL',          legal_number: '30100000058', tax_condition: :registered,    group: group_a },
  { legal_name: 'Distribuidora Central SA',  legal_number: '30100000066', tax_condition: :registered,    group: group_a },
  { legal_name: 'Importadora Patagonia SA',  legal_number: '30100000074', tax_condition: :registered,    group: group_a },
  { legal_name: 'Constructora Litoral SA',   legal_number: '30100000082', tax_condition: :registered,    group: group_a },

  # Group B — 7 clients
  { legal_name: 'Pyme Soluciones SRL',       legal_number: '30200000016', tax_condition: :registered,    group: group_b },
  { legal_name: 'Comercio Familiar SRL',     legal_number: '30200000024', tax_condition: :registered,    group: group_b },
  { legal_name: 'Servicios Rápidos SRL',     legal_number: '30200000032', tax_condition: :registered,    group: group_b },
  { legal_name: 'Taller del Centro SRL',     legal_number: '30200000049', tax_condition: :registered,    group: group_b },
  { legal_name: 'Logística Express SRL',     legal_number: '30200000057', tax_condition: :registered,    group: group_b },
  { legal_name: 'Consultora Regional SRL',   legal_number: '30200000065', tax_condition: :registered,    group: group_b },
  { legal_name: 'Agencia Digital SRL',       legal_number: '30200000073', tax_condition: :registered,    group: group_b },

  # Group C — 5 clients
  { legal_name: 'García Juan Carlos',        legal_number: '20300000015', tax_condition: :self_employed, group: group_c },
  { legal_name: 'López María Fernanda',      legal_number: '27300000023', tax_condition: :self_employed, group: group_c },
  { legal_name: 'Martínez Roberto',          legal_number: '20300000031', tax_condition: :self_employed, group: group_c },
  { legal_name: 'Rodríguez Ana Paula',       legal_number: '27300000048', tax_condition: :self_employed, group: group_c },
  { legal_name: 'Pérez Diego Hernán',        legal_number: '20300000056', tax_condition: :self_employed, group: group_c }
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
