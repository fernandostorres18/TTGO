// lib/services/data_service.dart
// Serviço central de dados com Hive

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/app_models.dart';

class DataService extends ChangeNotifier {
  static final DataService _instance = DataService._internal();
  factory DataService() => _instance;
  DataService._internal();

  late SharedPreferences _prefs;
  final _uuid = const Uuid();

  // In-memory collections
  List<AppUser> _users = [];
  List<Client> _clients = [];
  List<Product> _products = [];
  List<WarehouseAddress> _addresses = [];
  List<Lot> _lots = [];
  List<Order> _orders = [];
  List<ReceivingRecord> _receivings = [];
  List<MonthlyBilling> _billings = [];
  List<AppNotification> _notifications = [];

  // Current session
  AppUser? _currentUser;
  AppUser? get currentUser => _currentUser;
  bool get isAdmin => _currentUser?.role == UserRole.admin;
  bool get isOperator => _currentUser?.role == UserRole.operator;
  bool get isClient => _currentUser?.role == UserRole.client;

  // Filtered getters for current client
  String? get currentClientId => isClient ? _currentUser?.clientId : null;

  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadAll();
    if (_users.isEmpty) {
      await _seedDemoData();
    } else {
      // Migração: gerar separationTasks para pedidos que não têm
      await _migrateMissingSeparationTasks();
    }
  }

  // ─── PERSISTENCE ─────────────────────────────────────────────────────────

  /// Migração: pedidos em aguardandoSeparacao/separando sem tarefas recebem
  /// as tarefas geradas automaticamente via FIFO.
  Future<void> _migrateMissingSeparationTasks() async {
    bool changed = false;
    for (int i = 0; i < _orders.length; i++) {
      final order = _orders[i];
      final needsTasks = order.separationTasks.isEmpty &&
          (order.status == OrderStatus.aguardandoSeparacao ||
           order.status == OrderStatus.separando);
      if (!needsTasks) continue;

      final tasks = <SeparationTask>[];
      for (final item in order.items) {
        int remaining = item.quantity;
        final lots = getLotsByProduct(item.productId);
        for (final lot in lots) {
          if (remaining <= 0) break;
          if (!lot.isActive || lot.currentQuantity <= 0) continue;
          final take = remaining <= lot.currentQuantity ? remaining : lot.currentQuantity;
          tasks.add(SeparationTask(
            lotId: lot.id,
            lotBarcode: lot.barcode,
            addressCode: lot.addressCode,
            addressId: lot.addressId,
            productName: lot.productName,
            productSku: lot.productSku,
            quantity: take,
          ));
          remaining -= take;
        }
      }
      if (tasks.isNotEmpty) {
        _orders[i].separationTasks.addAll(tasks);
        changed = true;
      }
    }
    if (changed) {
      await _saveList('orders', _orders, (o) => o.toMap());
    }
  }

  Future<void> _loadAll() async {
    _users = _loadList('users', AppUser.fromMap);
    _clients = _loadList('clients', Client.fromMap);
    _products = _loadList('products', Product.fromMap);
    _addresses = _loadList('addresses', WarehouseAddress.fromMap);
    _lots = _loadList('lots', Lot.fromMap);
    _orders = _loadList('orders', Order.fromMap);
    _receivings = _loadList('receivings', ReceivingRecord.fromMap);
    _billings = _loadList('billings', MonthlyBilling.fromMap);
    _notifications = _loadList('notifications', AppNotification.fromMap);
  }

  List<T> _loadList<T>(String key, T Function(Map<String, dynamic>) fromMap) {
    final raw = _prefs.getString(key);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.map((e) => fromMap(Map<String, dynamic>.from(e))).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveList<T>(String key, List<T> list, Map<String, dynamic> Function(T) toMap) async {
    await _prefs.setString(key, jsonEncode(list.map(toMap).toList()));
  }

  Future<void> _saveAll() async {
    await Future.wait([
      _saveList('users', _users, (u) => u.toMap()),
      _saveList('clients', _clients, (c) => c.toMap()),
      _saveList('products', _products, (p) => p.toMap()),
      _saveList('addresses', _addresses, (a) => a.toMap()),
      _saveList('lots', _lots, (l) => l.toMap()),
      _saveList('orders', _orders, (o) => o.toMap()),
      _saveList('receivings', _receivings, (r) => r.toMap()),
      _saveList('billings', _billings, (b) => b.toMap()),
      _saveList('notifications', _notifications, (n) => n.toMap()),
    ]);
  }

  // ─── SEED DATA ────────────────────────────────────────────────────────────

  Future<void> _seedDemoData() async {
    final now = DateTime.now();

    // Admin user
    _users.add(AppUser(
      id: 'user-admin', name: 'Administrador', email: 'admin@fulfillment.com',
      password: '123456', role: UserRole.admin, createdAt: now,
    ));

    // Operator users
    _users.add(AppUser(
      id: 'user-op1', name: 'João Operador', email: 'operador@fulfillment.com',
      password: '123456', role: UserRole.operator, createdAt: now,
    ));
    _users.add(AppUser(
      id: 'user-op2', name: 'Marcelo Santos', email: 'marcelo@fulfillment.com',
      password: '123456', role: UserRole.operator, createdAt: now,
    ));
    _users.add(AppUser(
      id: 'user-op3', name: 'Fernanda Lima', email: 'fernanda@fulfillment.com',
      password: '123456', role: UserRole.operator, createdAt: now,
    ));

    // Clients
    final c1 = Client(
      id: 'client-1', companyName: 'TechStore LTDA', cnpjCpf: '12.345.678/0001-90',
      responsibleName: 'Carlos Silva', phone: '(11) 98765-4321', email: 'carlos@techstore.com',
      contractPlan: 'Premium', minimumMonthly: 1500, priceSmallOrder: 8,
      priceMediumOrder: 15, priceLargeOrder: 25, priceEnvelopeOrder: 4, createdAt: now,
    );
    final c2 = Client(
      id: 'client-2', companyName: 'ModaFlex S/A', cnpjCpf: '98.765.432/0001-10',
      responsibleName: 'Ana Beatriz', phone: '(21) 97654-3210', email: 'ana@modaflex.com',
      contractPlan: 'Básico', minimumMonthly: 800, priceSmallOrder: 6,
      priceMediumOrder: 12, priceLargeOrder: 20, priceEnvelopeOrder: 3, createdAt: now,
    );
    final c3 = Client(
      id: 'client-3', companyName: 'FarmaBem Ltda', cnpjCpf: '11.222.333/0001-44',
      responsibleName: 'Roberto Farmácia', phone: '(31) 96543-2109', email: 'roberto@farmabem.com',
      contractPlan: 'Enterprise', minimumMonthly: 3000, priceSmallOrder: 10,
      priceMediumOrder: 18, priceLargeOrder: 30, priceEnvelopeOrder: 5, createdAt: now,
    );
    _clients.addAll([c1, c2, c3]);

    // Client users
    _users.add(AppUser(
      id: 'user-c1', name: 'Carlos Silva', email: 'carlos@techstore.com',
      password: '123456', role: UserRole.client, clientId: 'client-1', createdAt: now,
    ));
    _users.add(AppUser(
      id: 'user-c2', name: 'Ana Beatriz', email: 'ana@modaflex.com',
      password: '123456', role: UserRole.client, clientId: 'client-2', createdAt: now,
    ));

    // Products
    final products = [
      Product(id: 'prod-1', clientId: 'client-1', sku: 'TECH-001', name: 'Smartphone Samsung A54',
        weightKg: 0.2, heightCm: 15, widthCm: 7, lengthCm: 1, minimumStock: 10, createdAt: now),
      Product(id: 'prod-2', clientId: 'client-1', sku: 'TECH-002', name: 'Notebook Dell 15"',
        weightKg: 2.5, heightCm: 38, widthCm: 26, lengthCm: 2.5, minimumStock: 5, createdAt: now),
      Product(id: 'prod-3', clientId: 'client-1', sku: 'TECH-003', name: 'Fone Bluetooth JBL',
        weightKg: 0.15, heightCm: 10, widthCm: 8, lengthCm: 5, minimumStock: 20, createdAt: now),
      Product(id: 'prod-4', clientId: 'client-2', sku: 'MODA-001', name: 'Camiseta Polo P',
        weightKg: 0.3, heightCm: 30, widthCm: 25, lengthCm: 3, minimumStock: 50, createdAt: now),
      Product(id: 'prod-5', clientId: 'client-2', sku: 'MODA-002', name: 'Calça Jeans 42',
        weightKg: 0.8, heightCm: 60, widthCm: 40, lengthCm: 5, minimumStock: 30, createdAt: now),
      Product(id: 'prod-6', clientId: 'client-3', sku: 'FARM-001', name: 'Vitamina C 500mg cx100',
        weightKg: 0.4, heightCm: 20, widthCm: 8, lengthCm: 6, minimumStock: 100, createdAt: now),
      Product(id: 'prod-7', clientId: 'client-3', sku: 'FARM-002', name: 'Protetor Solar FPS50',
        weightKg: 0.25, heightCm: 15, widthCm: 6, lengthCm: 4, minimumStock: 60, createdAt: now),
    ];
    _products.addAll(products);

    // Warehouse addresses
    for (var s in ['A', 'B', 'C']) {
      for (var m in ['01', '02', '03']) {
        for (var l in ['1', '2', '3']) {
          for (var p in ['01', '02', '03', '04']) {
            _addresses.add(WarehouseAddress(
              id: 'addr-$s$m$l$p',
              street: s, module: m, level: l, position: p,
            ));
          }
        }
      }
    }

    // Lots with stock
    final lots = [
      Lot(id: 'lot-1', clientId: 'client-1', productId: 'prod-1', productName: 'Smartphone Samsung A54',
        productSku: 'TECH-001', receivedQuantity: 50, currentQuantity: 35,
        receivedAt: now.subtract(const Duration(days: 15)), invoiceNumber: 'NF-001234',
        addressId: 'addr-A0111', addressCode: 'A-01-1-01', barcode: 'LOT-0001', isActive: true),
      Lot(id: 'lot-2', clientId: 'client-1', productId: 'prod-2', productName: 'Notebook Dell 15"',
        productSku: 'TECH-002', receivedQuantity: 10, currentQuantity: 10,
        receivedAt: now.subtract(const Duration(days: 10)), invoiceNumber: 'NF-001235',
        addressId: 'addr-A0121', addressCode: 'A-01-2-01', barcode: 'LOT-0002', isActive: true),
      Lot(id: 'lot-3', clientId: 'client-1', productId: 'prod-3', productName: 'Fone Bluetooth JBL',
        productSku: 'TECH-003', receivedQuantity: 100, currentQuantity: 72,
        receivedAt: now.subtract(const Duration(days: 8)), invoiceNumber: 'NF-001236',
        addressId: 'addr-A0131', addressCode: 'A-01-3-01', barcode: 'LOT-0003', isActive: true),
      Lot(id: 'lot-4', clientId: 'client-2', productId: 'prod-4', productName: 'Camiseta Polo P',
        productSku: 'MODA-001', receivedQuantity: 200, currentQuantity: 145,
        receivedAt: now.subtract(const Duration(days: 20)), invoiceNumber: 'NF-002100',
        addressId: 'addr-B0111', addressCode: 'B-01-1-01', barcode: 'LOT-0004', isActive: true),
      Lot(id: 'lot-5', clientId: 'client-2', productId: 'prod-5', productName: 'Calça Jeans 42',
        productSku: 'MODA-002', receivedQuantity: 80, currentQuantity: 4,
        receivedAt: now.subtract(const Duration(days: 30)), invoiceNumber: 'NF-002101',
        addressId: 'addr-B0121', addressCode: 'B-01-2-01', barcode: 'LOT-0005', isActive: true),
      Lot(id: 'lot-6', clientId: 'client-3', productId: 'prod-6', productName: 'Vitamina C 500mg',
        productSku: 'FARM-001', receivedQuantity: 500, currentQuantity: 480,
        receivedAt: now.subtract(const Duration(days: 5)), invoiceNumber: 'NF-003050',
        addressId: 'addr-C0111', addressCode: 'C-01-1-01', barcode: 'LOT-0006', isActive: true),
    ];
    _lots.addAll(lots);

    // Mark addresses as occupied
    for (final lot in lots) {
      final addrIdx = _addresses.indexWhere((a) => a.id == lot.addressId);
      if (addrIdx >= 0) {
        _addresses[addrIdx].isOccupied = true;
        _addresses[addrIdx].currentLotId = lot.id;
      }
    }

    // Orders
    final orders = [
      Order(id: 'ord-1', clientId: 'client-1', clientName: 'TechStore LTDA',
        invoiceNumber: 'NFV-5001', createdAt: now.subtract(const Duration(hours: 2)),
        createdByUserId: 'user-c1', createdByUserName: 'Carlos Silva',
        status: OrderStatus.aguardandoSeparacao, size: OrderSize.pequeno, orderValue: 8,
        items: [OrderItem(productId: 'prod-1', productName: 'Smartphone Samsung A54', sku: 'TECH-001', quantity: 2)],
        separationTasks: [
          SeparationTask(
            lotId: 'lot-1', lotBarcode: 'LOT-0001',
            addressCode: 'A-01-1-01', addressId: 'addr-A0111',
            productName: 'Smartphone Samsung A54', productSku: 'TECH-001',
            quantity: 2,
          ),
        ],
        events: [
          OrderEvent(id: 'ev-1a', date: now.subtract(const Duration(hours: 2)), userId: 'user-c1', userName: 'Carlos Silva', action: 'criado', description: 'Pedido criado pelo cliente'),
        ]),
      Order(id: 'ord-2', clientId: 'client-2', clientName: 'ModaFlex S/A',
        invoiceNumber: 'NFV-5002', createdAt: now.subtract(const Duration(hours: 4)),
        createdByUserId: 'user-op1', createdByUserName: 'João Operador',
        status: OrderStatus.separando, size: OrderSize.medio, orderValue: 12,
        items: [OrderItem(productId: 'prod-4', productName: 'Camiseta Polo P', sku: 'MODA-001', quantity: 10)],
        separationTasks: [
          SeparationTask(
            lotId: 'lot-4', lotBarcode: 'LOT-0004',
            addressCode: 'B-01-1-01', addressId: 'addr-B0111',
            productName: 'Camiseta Polo P', productSku: 'MODA-001',
            quantity: 10,
          ),
        ],
        events: [
          OrderEvent(id: 'ev-2a', date: now.subtract(const Duration(hours: 4)), userId: 'user-op1', userName: 'João Operador', action: 'criado', description: 'Pedido criado pelo operador'),
          OrderEvent(id: 'ev-2b', date: now.subtract(const Duration(hours: 3)), userId: 'user-op2', userName: 'Marcelo Santos', action: 'separacao_iniciada', description: 'Separação iniciada por Marcelo Santos'),
        ]),
      Order(id: 'ord-3', clientId: 'client-1', clientName: 'TechStore LTDA',
        invoiceNumber: 'NFV-5003', createdAt: now.subtract(const Duration(hours: 6)),
        createdByUserId: 'user-c1', createdByUserName: 'Carlos Silva',
        status: OrderStatus.faturado, size: OrderSize.grande, orderValue: 25,
        items: [OrderItem(productId: 'prod-2', productName: 'Notebook Dell 15"', sku: 'TECH-002', quantity: 3)],
        events: [
          OrderEvent(id: 'ev-3a', date: now.subtract(const Duration(hours: 6)), userId: 'user-c1', userName: 'Carlos Silva', action: 'criado', description: 'Pedido criado pelo cliente'),
          OrderEvent(id: 'ev-3b', date: now.subtract(const Duration(hours: 5)), userId: 'user-op2', userName: 'Marcelo Santos', action: 'separacao_iniciada', description: 'Separação iniciada'),
          OrderEvent(id: 'ev-3c', date: now.subtract(const Duration(hours: 4)), userId: 'user-op2', userName: 'Marcelo Santos', action: 'separacao_concluida', description: 'Separação concluída por Marcelo Santos'),
          OrderEvent(id: 'ev-3d', date: now.subtract(const Duration(hours: 3)), userId: 'user-admin', userName: 'Administrador', action: 'faturado', description: 'Pedido faturado'),
        ]),
      Order(id: 'ord-4', clientId: 'client-3', clientName: 'FarmaBem Ltda',
        invoiceNumber: 'NFV-5004', createdAt: now.subtract(const Duration(days: 1)),
        createdByUserId: 'user-op1', createdByUserName: 'João Operador',
        status: OrderStatus.enviado, size: OrderSize.pequeno, orderValue: 10,
        items: [OrderItem(productId: 'prod-6', productName: 'Vitamina C', sku: 'FARM-001', quantity: 20)],
        events: [
          OrderEvent(id: 'ev-4a', date: now.subtract(const Duration(days: 1)), userId: 'user-op1', userName: 'João Operador', action: 'criado', description: 'Pedido criado'),
          OrderEvent(id: 'ev-4b', date: now.subtract(const Duration(hours: 22)), userId: 'user-op3', userName: 'Fernanda Lima', action: 'separacao_iniciada', description: 'Separação iniciada por Fernanda Lima'),
          OrderEvent(id: 'ev-4c', date: now.subtract(const Duration(hours: 20)), userId: 'user-op3', userName: 'Fernanda Lima', action: 'separacao_concluida', description: 'Separação concluída'),
          OrderEvent(id: 'ev-4d', date: now.subtract(const Duration(hours: 18)), userId: 'user-admin', userName: 'Administrador', action: 'faturado', description: 'Faturado'),
          OrderEvent(id: 'ev-4e', date: now.subtract(const Duration(hours: 16)), userId: 'user-admin', userName: 'Administrador', action: 'enviado', description: 'Pedido enviado ao cliente'),
        ]),
      Order(id: 'ord-5', clientId: 'client-1', clientName: 'TechStore LTDA',
        invoiceNumber: 'NFV-5005', createdAt: now.subtract(const Duration(days: 2)),
        createdByUserId: 'user-c1', createdByUserName: 'Carlos Silva',
        status: OrderStatus.finalizado, size: OrderSize.pequeno, orderValue: 8, isBilled: true,
        items: [OrderItem(productId: 'prod-3', productName: 'Fone Bluetooth JBL', sku: 'TECH-003', quantity: 5)],
        events: [
          OrderEvent(id: 'ev-5a', date: now.subtract(const Duration(days: 2)), userId: 'user-c1', userName: 'Carlos Silva', action: 'criado', description: 'Pedido criado pelo cliente'),
          OrderEvent(id: 'ev-5b', date: now.subtract(const Duration(days: 1, hours: 22)), userId: 'user-op1', userName: 'João Operador', action: 'separacao_iniciada', description: 'Separação iniciada por João'),
          OrderEvent(id: 'ev-5c', date: now.subtract(const Duration(days: 1, hours: 20)), userId: 'user-op1', userName: 'João Operador', action: 'separacao_concluida', description: 'Separação concluída'),
          OrderEvent(id: 'ev-5d', date: now.subtract(const Duration(days: 1, hours: 18)), userId: 'user-admin', userName: 'Administrador', action: 'faturado', description: 'Faturado'),
          OrderEvent(id: 'ev-5e', date: now.subtract(const Duration(days: 1, hours: 12)), userId: 'user-admin', userName: 'Administrador', action: 'enviado', description: 'Enviado'),
          OrderEvent(id: 'ev-5f', date: now.subtract(const Duration(days: 1)), userId: 'user-admin', userName: 'Administrador', action: 'finalizado', description: 'Pedido finalizado'),
        ]),
    ];
    _orders.addAll(orders);

    // Monthly billing
    _billings.add(MonthlyBilling(
      id: 'bill-1', clientId: 'client-1', clientName: 'TechStore LTDA',
      year: now.year, month: now.month,
      smallOrders: 8, mediumOrders: 3, largeOrders: 2, envelopeOrders: 5,
      calculatedValue: 8*8 + 3*15 + 2*25 + 5*4, minimumMonthly: 1500,
      finalValue: (8*8 + 3*15 + 2*25 + 5*4).clamp(1500, double.infinity).toDouble(),
    ));

    await _saveAll();
    notifyListeners();
  }

  // ─── AUTH ─────────────────────────────────────────────────────────────────

  Future<bool> login(String email, String password) async {
    final user = _users.where((u) =>
      u.email.toLowerCase() == email.toLowerCase() &&
      u.password == password &&
      u.isActive
    ).firstOrNull;
    if (user != null) {
      _currentUser = user;
      notifyListeners();
      return true;
    }
    return false;
  }

  void logout() {
    _currentUser = null;
    notifyListeners();
  }

  // ─── CLIENTS ──────────────────────────────────────────────────────────────

  List<Client> get clients => List.unmodifiable(_clients);
  List<Client> get activeClients => _clients.where((c) => c.status == ClientStatus.ativo).toList();

  Client? getClient(String id) => _clients.where((c) => c.id == id).firstOrNull;

  Future<void> addClient(Client client) async {
    _clients.add(client);
    await _saveList('clients', _clients, (c) => c.toMap());
    notifyListeners();
  }

  Future<void> updateClient(Client client) async {
    final idx = _clients.indexWhere((c) => c.id == client.id);
    if (idx >= 0) {
      _clients[idx] = client;
      await _saveList('clients', _clients, (c) => c.toMap());
      notifyListeners();
    }
  }

  Future<bool> deleteClient(String clientId) async {
    // Verifica se tem pedidos ativos ou lotes
    final hasActiveOrders = _orders.any((o) =>
      o.clientId == clientId && o.status != OrderStatus.finalizado);
    if (hasActiveOrders) return false; // não permite exclusão
    _clients.removeWhere((c) => c.id == clientId);
    // Remove produtos e lotes associados (soft: apenas marca inativo)
    for (final p in _products.where((p) => p.clientId == clientId)) {
      p.isActive = false;
    }
    await _saveList('clients', _clients, (c) => c.toMap());
    await _saveList('products', _products, (p) => p.toMap());
    notifyListeners();
    return true;
  }

  String newClientId() => 'client-${_uuid.v4().substring(0, 8)}';

  // ─── PRODUCTS ─────────────────────────────────────────────────────────────

  List<Product> get allProducts => List.unmodifiable(_products);

  List<Product> getProductsByClient(String clientId) =>
      _products.where((p) => p.clientId == clientId && p.isActive).toList();

  List<Product> get currentClientProducts {
    if (isClient && currentClientId != null) return getProductsByClient(currentClientId!);
    return allProducts;
  }

  Product? getProduct(String id) => _products.where((p) => p.id == id).firstOrNull;
  Product? getProductBySku(String clientId, String sku) =>
      _products.where((p) => p.clientId == clientId && p.sku == sku).firstOrNull;

  Future<void> addProduct(Product product) async {
    _products.add(product);
    await _saveList('products', _products, (p) => p.toMap());
    notifyListeners();
  }

  Future<void> updateProduct(Product product) async {
    final idx = _products.indexWhere((p) => p.id == product.id);
    if (idx >= 0) {
      _products[idx] = product;
      await _saveList('products', _products, (p) => p.toMap());
      notifyListeners();
    }
  }

  Future<bool> deleteProduct(String productId) async {
    // Verifica se tem lotes ativos com estoque
    final hasActiveLots = _lots.any((l) =>
        l.productId == productId && l.isActive && l.currentQuantity > 0);
    if (hasActiveLots) return false;
    _products.removeWhere((p) => p.id == productId);
    await _saveList('products', _products, (p) => p.toMap());
    notifyListeners();
    return true;
  }

  String newProductId() => 'prod-${_uuid.v4().substring(0, 8)}';

  // ─── ADDRESSES ────────────────────────────────────────────────────────────

  List<WarehouseAddress> get allAddresses => List.unmodifiable(_addresses);
  List<WarehouseAddress> get freeAddresses =>
      _addresses.where((a) => !a.isOccupied).toList();

  WarehouseAddress? getAddress(String id) =>
      _addresses.where((a) => a.id == id).firstOrNull;
  WarehouseAddress? getAddressByCode(String code) =>
      _addresses.where((a) => a.code == code).firstOrNull;
  WarehouseAddress? getAddressByBarcode(String barcode) =>
      _addresses.where((a) => a.barcode == barcode).firstOrNull;

  Future<void> addAddress(WarehouseAddress address) async {
    _addresses.add(address);
    await _saveList('addresses', _addresses, (a) => a.toMap());
    notifyListeners();
  }

  Future<void> updateAddress(WarehouseAddress address) async {
    final idx = _addresses.indexWhere((a) => a.id == address.id);
    if (idx >= 0) {
      _addresses[idx] = address;
      await _saveList('addresses', _addresses, (a) => a.toMap());
      notifyListeners();
    }
  }

  String newAddressId() => 'addr-${_uuid.v4().substring(0, 8)}';

  // ─── LOTS ─────────────────────────────────────────────────────────────────

  List<Lot> get allLots => List.unmodifiable(_lots);

  List<Lot> getLotsByClient(String clientId) =>
      _lots.where((l) => l.clientId == clientId && l.isActive).toList();

  List<Lot> get currentClientLots {
    if (isClient && currentClientId != null) return getLotsByClient(currentClientId!);
    return _lots.where((l) => l.isActive).toList();
  }

  List<Lot> getLotsByProduct(String productId) =>
      _lots.where((l) => l.productId == productId && l.isActive && l.currentQuantity > 0)
          .toList()
          ..sort((a, b) => a.receivedAt.compareTo(b.receivedAt)); // FIFO

  int getStockByProduct(String productId) =>
      _lots.where((l) => l.productId == productId && l.isActive)
          .fold(0, (sum, l) => sum + l.currentQuantity);

  Lot? getLotByBarcode(String barcode) =>
      _lots.where((l) => l.barcode == barcode).firstOrNull;

  Future<Lot> createLot({
    required String clientId,
    required Product product,
    required int quantity,
    required String invoiceNumber,
    required String addressId,
    required String addressCode,
  }) async {
    final lotNumber = (_lots.length + 1).toString().padLeft(4, '0');
    final lot = Lot(
      id: 'lot-${_uuid.v4().substring(0, 8)}',
      clientId: clientId,
      productId: product.id,
      productName: product.name,
      productSku: product.sku,
      receivedQuantity: quantity,
      currentQuantity: quantity,
      receivedAt: DateTime.now(),
      invoiceNumber: invoiceNumber,
      addressId: addressId,
      addressCode: addressCode,
      barcode: 'LOT-$lotNumber',
      movements: [
        LotMovement(type: 'entrada', quantity: quantity, date: DateTime.now(),
          reference: invoiceNumber, description: 'Recebimento NF $invoiceNumber'),
      ],
    );
    _lots.add(lot);

    // Update address
    final addrIdx = _addresses.indexWhere((a) => a.id == addressId);
    if (addrIdx >= 0) {
      _addresses[addrIdx].isOccupied = true;
      _addresses[addrIdx].currentLotId = lot.id;
    }

    await _saveAll();

    // Notificar cliente que mercadoria foi recebida
    await _notifyClientUsers(
      clientId: clientId,
      type: NotificationType.stockReceived,
      title: 'Mercadoria Recebida — ${product.name}',
      body: 'Recebidas $quantity unidades de ${product.name} (NF $invoiceNumber). Lote: ${lot.barcode}.',
      referenceId: lot.id,
    );

    notifyListeners();
    return lot;
  }

  Future<void> deductFromLot(String lotId, int quantity, String orderId) async {
    final idx = _lots.indexWhere((l) => l.id == lotId);
    if (idx >= 0) {
      _lots[idx].currentQuantity -= quantity;
      _lots[idx].movements.add(LotMovement(
        type: 'saida', quantity: quantity, date: DateTime.now(),
        reference: orderId, description: 'Saída pedido $orderId',
      ));
      if (_lots[idx].currentQuantity <= 0) {
        _lots[idx].isActive = false;
        // Free address
        final addrIdx = _addresses.indexWhere((a) => a.id == _lots[idx].addressId);
        if (addrIdx >= 0) {
          _addresses[addrIdx].isOccupied = false;
          _addresses[addrIdx].currentLotId = null;
        }
      }
      await _saveAll();
      notifyListeners();
    }
  }

  Future<bool> deleteLot(String lotId) async {
    final lot = _lots.where((l) => l.id == lotId).firstOrNull;
    if (lot == null) return false;
    // Não permite excluir lote que está em separação ativa
    final inSeparation = _orders.any((o) =>
        (o.status == OrderStatus.separando || o.status == OrderStatus.aguardandoSeparacao) &&
        o.separationTasks.any((t) => t.lotId == lotId));
    if (inSeparation) return false;

    _lots.removeWhere((l) => l.id == lotId);

    // Libera o endereço se estava ocupado por este lote
    final addrIdx = _addresses.indexWhere((a) => a.currentLotId == lotId);
    if (addrIdx >= 0) {
      _addresses[addrIdx].isOccupied = false;
      _addresses[addrIdx].currentLotId = null;
    }

    await _saveAll();
    notifyListeners();
    return true;
  }

  String newLotId() => 'lot-${_uuid.v4().substring(0, 8)}';

  // ─── ORDERS ───────────────────────────────────────────────────────────────

  List<Order> get allOrders => List.unmodifiable(_orders);

  List<Order> getOrdersByClient(String clientId) =>
      _orders.where((o) => o.clientId == clientId).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  List<Order> get currentClientOrders {
    if (isClient && currentClientId != null) return getOrdersByClient(currentClientId!);
    return List.from(_orders)..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Order? getOrder(String id) => _orders.where((o) => o.id == id).firstOrNull;

  List<Order> getTodayOrders() {
    final today = DateTime.now();
    return _orders.where((o) =>
      o.createdAt.year == today.year &&
      o.createdAt.month == today.month &&
      o.createdAt.day == today.day
    ).toList();
  }

  Future<Order> createOrderFromXml({
    required String clientId,
    required String invoiceNumber,
    required List<OrderItem> items,
    OrderSize? manualSize, // se passado, ignora cálculo automático
  }) async {
    final client = getClient(clientId);
    final creatorId = _currentUser?.id ?? '';
    final creatorName = _currentUser?.name ?? 'Sistema';
    // Calculate order size based on items (only if not manually chosen)
    OrderSize size;
    if (manualSize != null) {
      size = manualSize;
    } else {
      size = OrderSize.pequeno;
      for (final item in items) {
        final product = getProduct(item.productId);
        if (product != null) {
          item.itemSize = product.orderSize;
          if (product.orderSize == OrderSize.grande) size = OrderSize.grande;
          else if (product.orderSize == OrderSize.medio && size == OrderSize.pequeno) size = OrderSize.medio;
        }
      }
    }

    // Generate separation tasks (FIFO)
    final tasks = <SeparationTask>[];
    for (final item in items) {
      int remaining = item.quantity;
      final lots = getLotsByProduct(item.productId);
      for (final lot in lots) {
        if (remaining <= 0) break;
        final take = remaining <= lot.currentQuantity ? remaining : lot.currentQuantity;
        tasks.add(SeparationTask(
          lotId: lot.id,
          lotBarcode: lot.barcode,
          addressCode: lot.addressCode,
          addressId: lot.addressId,
          productName: lot.productName,
          productSku: lot.productSku,
          quantity: take,
        ));
        remaining -= take;
      }
    }

    // Calculate order value
    double value = 0;
    if (client != null) {
      value = size == OrderSize.pequeno ? client.priceSmallOrder
           : size == OrderSize.medio ? client.priceMediumOrder
           : size == OrderSize.envelope ? client.priceEnvelopeOrder
           : client.priceLargeOrder;
    }

    final now = DateTime.now();
    final orderId = 'ord-${_uuid.v4().substring(0, 8)}';
    final order = Order(
      id: orderId,
      clientId: clientId,
      clientName: client?.companyName ?? 'Cliente',
      invoiceNumber: invoiceNumber,
      createdAt: now,
      createdByUserId: creatorId,
      createdByUserName: creatorName,
      status: OrderStatus.aguardandoSeparacao,
      size: size,
      orderValue: value,
      items: items,
      separationTasks: tasks,
      events: [
        OrderEvent(
          id: 'ev-${_uuid.v4().substring(0, 8)}',
          date: now,
          userId: creatorId,
          userName: creatorName,
          action: 'criado',
          description: 'Pedido criado por $creatorName',
        ),
      ],
    );
    _orders.add(order);
    await _saveList('orders', _orders, (o) => o.toMap());

    // Notificar admins e operadores sobre novo pedido
    await _notifyAdminsAndOperators(
      type: NotificationType.newOrder,
      title: 'Novo Pedido — ${client?.companyName ?? clientId}',
      body: 'Pedido $invoiceNumber criado por $creatorName aguardando separação.',
      referenceId: orderId,
    );

    notifyListeners();
    return order;
  }

  Future<void> updateOrderStatus(String orderId, OrderStatus status) async {
    final idx = _orders.indexWhere((o) => o.id == orderId);
    if (idx >= 0) {
      _orders[idx].status = status;
      _orders[idx].updatedAt = DateTime.now();

      final updaterId = _currentUser?.id ?? '';
      final updaterName = _currentUser?.name ?? 'Sistema';
      final order = _orders[idx];

      // Se está iniciando separação e não há tarefas, gera automaticamente (FIFO)
      if (status == OrderStatus.separando && order.separationTasks.isEmpty) {
        final tasks = <SeparationTask>[];
        for (final item in order.items) {
          int remaining = item.quantity;
          final lots = getLotsByProduct(item.productId);
          for (final lot in lots) {
            if (remaining <= 0) break;
            if (!lot.isActive || lot.currentQuantity <= 0) continue;
            final take = remaining <= lot.currentQuantity ? remaining : lot.currentQuantity;
            tasks.add(SeparationTask(
              lotId: lot.id,
              lotBarcode: lot.barcode,
              addressCode: lot.addressCode,
              addressId: lot.addressId,
              productName: lot.productName,
              productSku: lot.productSku,
              quantity: take,
            ));
            remaining -= take;
          }
        }
        _orders[idx].separationTasks.addAll(tasks);
      }

      String action = '';
      String description = '';
      switch (status) {
        case OrderStatus.separando:
          action = 'separacao_iniciada';
          description = 'Separação iniciada por $updaterName';
          break;
        case OrderStatus.faturado:
          action = 'separacao_concluida';
          description = 'Separação concluída por $updaterName';
          break;
        case OrderStatus.enviado:
          action = 'enviado';
          description = 'Pedido marcado como enviado por $updaterName';
          break;
        case OrderStatus.finalizado:
          action = 'finalizado';
          description = 'Pedido finalizado por $updaterName';
          break;
        default:
          action = status.name;
          description = 'Status atualizado para ${status.label} por $updaterName';
      }

      if (action.isNotEmpty) {
        _orders[idx].events.add(OrderEvent(
          id: 'ev-${_uuid.v4().substring(0, 8)}',
          date: DateTime.now(),
          userId: updaterId,
          userName: updaterName,
          action: action,
          description: description,
        ));
      }

      await _saveList('orders', _orders, (o) => o.toMap());

      // Notificar cliente sobre atualização do pedido
      await _notifyClientUsers(
        clientId: order.clientId,
        type: NotificationType.orderStatus,
        title: 'Pedido ${order.invoiceNumber} — ${status.label}',
        body: description,
        referenceId: orderId,
      );

      notifyListeners();
    }
  }

  /// Marca uma tarefa de separação como concluída (por lotId) e persiste no storage
  Future<void> completeTask(String orderId, String lotId) async {
    final idx = _orders.indexWhere((o) => o.id == orderId);
    if (idx < 0) return;
    final taskIdx = _orders[idx].separationTasks.indexWhere((t) => t.lotId == lotId && !t.isCompleted);
    if (taskIdx < 0) return;
    _orders[idx].separationTasks[taskIdx].isCompleted = true;
    _orders[idx].separationTasks[taskIdx].addressScanned = true;
    _orders[idx].separationTasks[taskIdx].lotScanned = true;
    await _saveList('orders', _orders, (o) => o.toMap());
    notifyListeners();
  }

  Future<void> completeSeparation(String orderId) async {
    final order = getOrder(orderId);
    if (order == null) return;
    // Deduct from lots
    for (final task in order.separationTasks) {
      await deductFromLot(task.lotId, task.quantity, orderId);
    }
    await updateOrderStatus(orderId, OrderStatus.faturado);
  }

  // ─── RECEIVINGS ───────────────────────────────────────────────────────────

  List<ReceivingRecord> get allReceivings => List.unmodifiable(_receivings);

  List<ReceivingRecord> getReceivingsByClient(String clientId) =>
      _receivings.where((r) => r.clientId == clientId).toList()
        ..sort((a, b) => b.receivedAt.compareTo(a.receivedAt));

  Future<void> addReceiving(ReceivingRecord record) async {
    _receivings.add(record);
    await _saveList('receivings', _receivings, (r) => r.toMap());
    notifyListeners();
  }

  String newReceivingId() => 'rec-${_uuid.v4().substring(0, 8)}';
  String newOrderId() => 'ord-${_uuid.v4().substring(0, 8)}';

  // ─── USERS MANAGEMENT ────────────────────────────────────────────────────

  List<AppUser> get allUsers => List.unmodifiable(_users);
  List<AppUser> get operatorUsers => _users.where((u) => u.role == UserRole.operator).toList();
  List<AppUser> get clientUsers => _users.where((u) => u.role == UserRole.client).toList();

  Future<void> addUser(AppUser user) async {
    _users.add(user);
    await _saveList('users', _users, (u) => u.toMap());
    notifyListeners();
  }

  Future<void> updateUser(AppUser user) async {
    final idx = _users.indexWhere((u) => u.id == user.id);
    if (idx >= 0) {
      _users[idx] = user;
      await _saveList('users', _users, (u) => u.toMap());
      notifyListeners();
    }
  }

  Future<bool> deleteUser(String userId) async {
    if (userId == 'user-admin') return false; // protege o admin principal
    _users.removeWhere((u) => u.id == userId);
    await _saveList('users', _users, (u) => u.toMap());
    notifyListeners();
    return true;
  }

  bool emailExists(String email, {String? excludeId}) {
    return _users.any((u) => u.email.toLowerCase() == email.toLowerCase() && u.id != excludeId);
  }

  String newUserId() => 'user-${_uuid.v4().substring(0, 8)}';

  // ─── NOTIFICATIONS ────────────────────────────────────────────────────────

  List<AppNotification> get allNotifications => List.unmodifiable(_notifications);

  List<AppNotification> getNotificationsForUser(String userId) =>
      _notifications.where((n) => n.targetUserId == userId)
          .toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  int unreadCountForUser(String userId) =>
      _notifications.where((n) => n.targetUserId == userId && !n.isRead).length;

  int get currentUserUnreadCount =>
      _currentUser != null ? unreadCountForUser(_currentUser!.id) : 0;

  Future<void> addNotification(AppNotification notification) async {
    _notifications.add(notification);
    await _saveList('notifications', _notifications, (n) => n.toMap());
    notifyListeners();
  }

  Future<void> markNotificationRead(String notificationId) async {
    final idx = _notifications.indexWhere((n) => n.id == notificationId);
    if (idx >= 0) {
      _notifications[idx].isRead = true;
      await _saveList('notifications', _notifications, (n) => n.toMap());
      notifyListeners();
    }
  }

  Future<void> markAllNotificationsRead(String userId) async {
    for (final n in _notifications.where((n) => n.targetUserId == userId)) {
      n.isRead = true;
    }
    await _saveList('notifications', _notifications, (n) => n.toMap());
    notifyListeners();
  }

  String newNotificationId() => 'notif-${_uuid.v4().substring(0, 8)}';

  /// Cria notificações para todos os admins e operadores
  Future<void> _notifyAdminsAndOperators({
    required NotificationType type,
    required String title,
    required String body,
    String? referenceId,
  }) async {
    final targets = _users.where((u) =>
        u.role == UserRole.admin || u.role == UserRole.operator);
    for (final u in targets) {
      _notifications.add(AppNotification(
        id: newNotificationId(), targetUserId: u.id,
        type: type, title: title, body: body,
        referenceId: referenceId, createdAt: DateTime.now(),
      ));
    }
    await _saveList('notifications', _notifications, (n) => n.toMap());
    notifyListeners();
  }

  /// Cria notificação para usuários de um cliente específico
  Future<void> _notifyClientUsers({
    required String clientId,
    required NotificationType type,
    required String title,
    required String body,
    String? referenceId,
  }) async {
    final targets = _users.where((u) => u.clientId == clientId);
    for (final u in targets) {
      _notifications.add(AppNotification(
        id: newNotificationId(), targetUserId: u.id,
        type: type, title: title, body: body,
        referenceId: referenceId, createdAt: DateTime.now(),
      ));
    }
    await _saveList('notifications', _notifications, (n) => n.toMap());
    notifyListeners();
  }

  // ─── USER STATS (produtividade) ───────────────────────────────────────────

  List<UserStats> getUserStats() {
    final statsMap = <String, UserStats>{};

    // Inicializa para todos usuários ativos não-client
    for (final u in _users.where((u) => u.role != UserRole.client && u.isActive)) {
      statsMap[u.id] = UserStats(userId: u.id, userName: u.name, role: u.role);
    }
    // Também inicializa para clientes ativos
    for (final u in _users.where((u) => u.role == UserRole.client && u.isActive)) {
      statsMap[u.id] = UserStats(userId: u.id, userName: u.name, role: u.role);
    }

    // Conta ações por pedido/eventos
    for (final o in _orders) {
      for (final ev in o.events) {
        final stats = statsMap[ev.userId];
        if (stats == null) continue;
        switch (ev.action) {
          case 'criado':
            stats.ordersCreated++;
            break;
          case 'separacao_iniciada':
          case 'separacao_concluida':
            stats.separationsCount++;
            break;
          case 'enviado':
            stats.shippedCount++;
            break;
          case 'finalizado':
            stats.finalizedCount++;
            break;
        }
      }
    }

    // Conta recebimentos
    for (final r in _receivings) {
      // Busca usuário pelo nome do operador
      final u = _users.where((u) => u.name == r.operatorName).firstOrNull;
      if (u != null && statsMap.containsKey(u.id)) {
        statsMap[u.id]!.receivingsCount++;
      }
    }

    return statsMap.values.toList()
      ..sort((a, b) => b.totalActions.compareTo(a.totalActions));
  }

  // ─── BILLING ──────────────────────────────────────────────────────────────

  List<MonthlyBilling> get allBillings => List.unmodifiable(_billings);

  MonthlyBilling? getBillingForClient(String clientId, int year, int month) =>
      _billings.where((b) => b.clientId == clientId && b.year == year && b.month == month).firstOrNull;

  Future<MonthlyBilling> calculateMonthlyBilling(String clientId, int year, int month) async {
    final client = getClient(clientId);
    if (client == null) throw Exception('Cliente não encontrado');

    final orders = getOrdersByClient(clientId).where((o) =>
      o.createdAt.year == year && o.createdAt.month == month &&
      o.status != OrderStatus.recebido
    ).toList();

    int small = 0, medium = 0, large = 0, envelope = 0;
    for (final o in orders) {
      if (o.size == OrderSize.pequeno) small++;
      else if (o.size == OrderSize.medio) medium++;
      else if (o.size == OrderSize.envelope) envelope++;
      else large++;
    }

    final calc = small * client.priceSmallOrder +
        medium * client.priceMediumOrder +
        large * client.priceLargeOrder +
        envelope * client.priceEnvelopeOrder;

    final final_ = calc < client.minimumMonthly ? client.minimumMonthly : calc;

    // Remove existing
    _billings.removeWhere((b) => b.clientId == clientId && b.year == year && b.month == month);

    final billing = MonthlyBilling(
      id: 'bill-${_uuid.v4().substring(0, 8)}',
      clientId: clientId, clientName: client.companyName,
      year: year, month: month,
      smallOrders: small, mediumOrders: medium, largeOrders: large,
      envelopeOrders: envelope,
      calculatedValue: calc, minimumMonthly: client.minimumMonthly, finalValue: final_,
    );
    _billings.add(billing);
    await _saveList('billings', _billings, (b) => b.toMap());
    notifyListeners();
    return billing;
  }

  // ─── DASHBOARD STATS ──────────────────────────────────────────────────────

  Map<String, dynamic> getAdminDashboardStats() {
    final today = DateTime.now();
    final todayOrders = getTodayOrders();
    final monthOrders = _orders.where((o) =>
      o.createdAt.year == today.year && o.createdAt.month == today.month).toList();

    double monthRevenue = 0;
    for (final o in monthOrders) {
      monthRevenue += o.orderValue;
    }

    // Low stock alerts
    final lowStockProducts = <Product>[];
    for (final p in _products.where((p) => p.isActive)) {
      final stock = getStockByProduct(p.id);
      if (stock <= p.minimumStock) lowStockProducts.add(p);
    }

    return {
      'todayOrders': todayOrders.length,
      'monthOrders': monthOrders.length,
      'pendingOrders': _orders.where((o) =>
        o.status == OrderStatus.aguardandoSeparacao || o.status == OrderStatus.separando).length,
      'monthRevenue': monthRevenue,
      'activeClients': activeClients.length,
      'totalLots': _lots.where((l) => l.isActive).length,
      'lowStockAlerts': lowStockProducts.length,
      'lowStockProducts': lowStockProducts,
      'ordersByStatus': {
        for (final s in OrderStatus.values)
          s.label: _orders.where((o) => o.status == s).length,
      },
    };
  }

  // XML parsing simulation
  List<Map<String, dynamic>> parseInvoiceXml(String xmlContent) {
    try {
      final items = <Map<String, dynamic>>[];
      // Simple XML parsing for NF-e products
      final regex = RegExp(r'<det[^>]*>(.*?)</det>', dotAll: true);
      final prodRegex = RegExp(r'<xProd>(.*?)</xProd>');
      final qcomRegex = RegExp(r'<qCom>(.*?)</qCom>');
      final cprodRegex = RegExp(r'<cProd>(.*?)</cProd>');

      for (final match in regex.allMatches(xmlContent)) {
        final det = match.group(1) ?? '';
        final name = prodRegex.firstMatch(det)?.group(1) ?? 'Produto';
        final qty = double.tryParse(qcomRegex.firstMatch(det)?.group(1) ?? '1') ?? 1;
        final sku = cprodRegex.firstMatch(det)?.group(1) ?? '';
        items.add({'name': name, 'quantity': qty.toInt(), 'sku': sku});
      }
      return items;
    } catch (_) {
      return [];
    }
  }

  // ─── HISTÓRICO GLOBAL ─────────────────────────────────────────────────────

  /// Retorna todos os eventos de todos os pedidos, ordenados do mais recente.
  /// Cada item contém o evento + contexto do pedido.
  List<GlobalEvent> getGlobalEvents() {
    final result = <GlobalEvent>[];
    for (final order in _orders) {
      for (final ev in order.events) {
        result.add(GlobalEvent(
          event: ev,
          orderId: order.id,
          invoiceNumber: order.invoiceNumber,
          clientName: order.clientName,
          clientId: order.clientId,
        ));
      }
    }
    result.sort((a, b) => b.event.date.compareTo(a.event.date));
    return result;
  }
}
