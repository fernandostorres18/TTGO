// lib/services/data_service.dart
// Serviço central de dados — Firestore (nuvem) + SharedPreferences (sessão local)

import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/app_models.dart';

class DataService extends ChangeNotifier {
  static final DataService _instance = DataService._internal();
  factory DataService() => _instance;
  DataService._internal();

  late SharedPreferences _prefs;  // apenas para sessão (usuário logado)
  final _uuid = const Uuid();
  final _db = FirebaseFirestore.instance;

  // Listeners em tempo real do Firestore — atualizam a UI automaticamente
  final List<StreamSubscription> _subs = [];

  void startAutoRefresh() {
    // Firestore já envia atualizações em tempo real via streams.
    // Apenas iniciamos os listeners se ainda não estiverem ativos.
    if (_subs.isNotEmpty) return;
    _listenAll();
  }

  void stopAutoRefresh() {
    for (final s in _subs) { s.cancel(); }
    _subs.clear();
  }

  // Conecta listeners em tempo real para todas as coleções
  void _listenAll() {
    void listen<T>(String col, T Function(Map<String,dynamic>) from, void Function(List<T>) set) {
      _subs.add(_db.collection(col).snapshots().listen((snap) {
        // Parse seguro: ignora documentos com erro, não descarta os bons
        final result = <T>[];
        for (final d in snap.docs) {
          try {
            final data = Map<String,dynamic>.from(d.data());
            data['id'] = d.id;
            result.add(from(data));
          } catch (_) {
            // ignora só este doc, continua os demais
          }
        }
        set(result);
        notifyListeners();
      }, onError: (_) {
        // Erro no stream (ex: regras Firestore) — libera o loading mesmo assim
        if (!(_usersReadyCompleter?.isCompleted ?? true)) {
          _usersReadyCompleter!.complete();
        }
        notifyListeners();
      }));
    }
    listen('users', AppUser.fromMap, (v) {
      _users = v;
      // Resolve o completer assim que usuários chegarem (mesmo lista vazia = Firestore respondeu)
      if (!(_usersReadyCompleter?.isCompleted ?? true)) {
        _usersReadyCompleter!.complete();
      }
    });
    listen('clients',      Client.fromMap,           (v) => _clients = v);
    listen('products',     Product.fromMap,          (v) => _products = v);
    listen('addresses',    WarehouseAddress.fromMap, (v) => _addresses = v);
    listen('lots',         Lot.fromMap,              (v) => _lots = v);
    listen('orders',       Order.fromMap,            (v) => _orders = v);
    listen('receivings',   ReceivingRecord.fromMap,  (v) => _receivings = v);
    listen('billings',     MonthlyBilling.fromMap,   (v) => _billings = v);
    listen('notifications',AppNotification.fromMap,  (v) => _notifications = v);
    listen('packageTypes', PackageType.fromMap,      (v) => _packageTypes = v);
    listen('tickets',      SupportTicket.fromMap,    (v) => _tickets = v);
    listen('billingExtras',BillingExtra.fromMap,     (v) => _billingExtras = v);
    listen('archivedOrders',Order.fromMap,           (v) => _archivedOrders = v);
    _db.collection('settings').doc('support').snapshots().listen((snap) {
      if (snap.exists) {
        try { _supportSettings = SupportSettings.fromMap(
          Map<String,dynamic>.from(snap.data()!)); } catch(_) {}
        notifyListeners();
      }
    }, onError: (_) {});
  }

  @override
  void dispose() {
    stopAutoRefresh();
    super.dispose();
  }

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
  List<PackageType> _packageTypes = [];
  List<SupportTicket> _tickets = [];
  List<BillingExtra> _billingExtras = [];
  SupportSettings _supportSettings = SupportSettings();

  // Current session
  AppUser? _currentUser;
  AppUser? get currentUser => _currentUser;
  bool get isAdmin => _currentUser?.role == UserRole.admin;
  bool get isOperator => _currentUser?.role == UserRole.operator;
  bool get isClient => _currentUser?.role == UserRole.client;
  bool get isSupportAgent => _currentUser?.role == UserRole.supportAgent;
  bool get isStaff => isAdmin || isOperator || isSupportAgent;

  // Filtered getters for current client
  String? get currentClientId => isClient ? _currentUser?.clientId : null;

  // Flag: true enquanto o primeiro carregamento do Firestore não terminou
  bool _initializing = true;
  bool get isInitializing => _initializing;

  // Completer que resolve quando _users tiver pelo menos 1 elemento
  Completer<void>? _usersReadyCompleter;

  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    _usersReadyCompleter = Completer<void>();

    // Liga os streams em tempo real — eles populam os dados automaticamente
    startAutoRefresh();

    // Aguarda o Firestore responder (usuários chegarem OU erro) — máx 10s
    try {
      await _usersReadyCompleter!.future.timeout(const Duration(seconds: 10));
    } catch (_) {
      // Timeout: libera a tela mesmo assim
    }

    // Seed apenas se o Firestore não retornou nenhum usuário
    if (_users.isEmpty) {
      try { await _seedDemoData(); } catch (_) {}
    }

    _initializing = false;
    notifyListeners();
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
      await _saveCollection('orders', _orders, (o) => o.toMap(), (o) => o.id);
    }
  }

  /// Migração: cria tickets de chat demo se ainda não existirem
  Future<void> _migrateDemoChatTickets() async {
    // Garante que o atendente de teste existe mesmo em bases antigas
    if (!_users.any((u) => u.id == 'user-agent1')) {
      _users.add(AppUser(
        id: 'user-agent1', name: 'Ana Atendente', email: 'atendente@fulfillment.com',
        password: '123456', role: UserRole.supportAgent, createdAt: DateTime.now(),
      ));
      await _saveCollection('users', _users, (u) => u.toMap(), (u) => u.id);
    }

    final hasDemo = _tickets.any((t) => t.id == 'ticket-demo-1');
    if (hasDemo) return;

    final now = DateTime.now();

    // Verifica se os clientes demo existem
    final hasClient1 = _clients.any((c) => c.id == 'client-1');
    final hasClient2 = _clients.any((c) => c.id == 'client-2');

    if (hasClient1) {
      _tickets.add(SupportTicket(
        id: 'ticket-demo-1',
        clientId: 'client-1',
        clientName: 'TechStore LTDA',
        createdByUserId: 'user-c1',
        createdByUserName: 'Carlos Silva',
        status: TicketStatus.inProgress,
        category: TicketCategory.general,
        subject: 'Chat com suporte',
        assignedToUserId: 'user-admin',
        assignedToUserName: 'Administrador',
        createdAt: now.subtract(const Duration(hours: 3)),
        updatedAt: now.subtract(const Duration(minutes: 30)),
        messages: [
          TicketMessage(
            id: 'msg-d1-1', senderId: 'user-c1', senderName: 'Carlos Silva',
            senderRole: UserRole.client,
            text: 'Olá! Gostaria de saber o status do meu pedido NFV-5001.',
            sentAt: now.subtract(const Duration(hours: 3)),
          ),
          TicketMessage(
            id: 'msg-d1-2', senderId: 'user-admin', senderName: 'Administrador',
            senderRole: UserRole.admin,
            text: 'Olá Carlos! Seu pedido NFV-5001 está em separação. Deve ficar pronto ainda hoje.',
            sentAt: now.subtract(const Duration(hours: 2, minutes: 45)),
          ),
          TicketMessage(
            id: 'msg-d1-3', senderId: 'user-c1', senderName: 'Carlos Silva',
            senderRole: UserRole.client,
            text: 'Ótimo, obrigado! Quando será enviado?',
            sentAt: now.subtract(const Duration(minutes: 30)),
          ),
        ],
      ));
    }

    if (hasClient2) {
      _tickets.add(SupportTicket(
        id: 'ticket-demo-2',
        clientId: 'client-2',
        clientName: 'ModaFlex S/A',
        createdByUserId: 'user-c2',
        createdByUserName: 'Ana Beatriz',
        status: TicketStatus.open,
        category: TicketCategory.billing,
        subject: 'Chat com suporte',
        createdAt: now.subtract(const Duration(hours: 1)),
        updatedAt: now.subtract(const Duration(minutes: 10)),
        messages: [
          TicketMessage(
            id: 'msg-d2-1', senderId: 'user-c2', senderName: 'Ana Beatriz',
            senderRole: UserRole.client,
            text: 'Boa tarde! Tenho uma dúvida sobre a fatura do mês.',
            sentAt: now.subtract(const Duration(hours: 1)),
          ),
          TicketMessage(
            id: 'msg-d2-2', senderId: 'user-c2', senderName: 'Ana Beatriz',
            senderRole: UserRole.client,
            text: 'O valor cobrado parece diferente do contrato. Podem verificar?',
            sentAt: now.subtract(const Duration(minutes: 10)),
          ),
        ],
      ));
    }

    await _saveCollection('tickets', _tickets, (t) => t.toMap(), (t) => t.id);
    notifyListeners();
  }

  // Carrega todas as coleções do Firestore de uma vez (one-shot para inicialização)
  Future<void> _loadAll() async {
    Future<List<T>> fetch<T>(String col, T Function(Map<String,dynamic>) from) async {
      try {
        final snap = await _db.collection(col).get();
        return snap.docs.map((d) {
          final data = Map<String,dynamic>.from(d.data());
          data['id'] = d.id;
          return from(data);
        }).toList();
      } catch (_) { return []; }
    }
    _users         = await fetch('users',         AppUser.fromMap);
    _clients       = await fetch('clients',        Client.fromMap);
    _products      = await fetch('products',       Product.fromMap);
    _addresses     = await fetch('addresses',      WarehouseAddress.fromMap);
    _lots          = await fetch('lots',           Lot.fromMap);
    _orders        = await fetch('orders',         Order.fromMap);
    _receivings    = await fetch('receivings',     ReceivingRecord.fromMap);
    _billings      = await fetch('billings',       MonthlyBilling.fromMap);
    _notifications = await fetch('notifications',  AppNotification.fromMap);
    _packageTypes  = await fetch('packageTypes',   PackageType.fromMap);
    _tickets       = await fetch('tickets',        SupportTicket.fromMap);
    _billingExtras = await fetch('billingExtras',  BillingExtra.fromMap);
    _archivedOrders = await fetch('archivedOrders', Order.fromMap);
    // Support settings
    try {
      final snap = await _db.collection('settings').doc('support').get();
      if (snap.exists) {
        _supportSettings = SupportSettings.fromMap(Map<String,dynamic>.from(snap.data()!));
      }
    } catch (_) {}
    if (_packageTypes.isEmpty) _seedPackageTypes();
  }

  // Salva UM documento no Firestore
  Future<void> _saveDoc(String collection, String id, Map<String,dynamic> data) async {
    data.remove('id'); // Firestore usa o ID do documento, não um campo
    await _db.collection(collection).doc(id).set(data);
  }

  // Deleta UM documento no Firestore
  Future<void> _deleteDoc(String collection, String id) async {
    await _db.collection(collection).doc(id).delete();
  }

  // Salva toda uma coleção no Firestore (útil após operações em lote)
  Future<void> _saveCollection<T>(
      String col, List<T> list, Map<String,dynamic> Function(T) toMap, String Function(T) getId) async {
    for (final item in list) {
      await _saveDoc(col, getId(item), toMap(item));
    }
  }

  // Salva lista inteira (usado apenas no seed inicial)
  Future<void> _saveAll() async {
    final batch = _db.batch();
    void batchList<T>(String col, List<T> list, Map<String,dynamic> Function(T) toMap, String Function(T) getId) {
      for (final item in list) {
        final data = toMap(item);
        final id = getId(item);
        data.remove('id');
        batch.set(_db.collection(col).doc(id), data);
      }
    }
    batchList('users',         _users,         (u) => u.toMap(), (u) => u.id);
    batchList('clients',       _clients,        (c) => c.toMap(), (c) => c.id);
    batchList('products',      _products,       (p) => p.toMap(), (p) => p.id);
    batchList('addresses',     _addresses,      (a) => a.toMap(), (a) => a.id);
    batchList('lots',          _lots,           (l) => l.toMap(), (l) => l.id);
    batchList('orders',        _orders,         (o) => o.toMap(), (o) => o.id);
    batchList('receivings',    _receivings,     (r) => r.toMap(), (r) => r.id);
    batchList('billings',      _billings,       (b) => b.toMap(), (b) => b.id);
    batchList('notifications', _notifications,  (n) => n.toMap(), (n) => n.id);
    batchList('packageTypes',  _packageTypes,   (pt) => pt.toMap(), (pt) => pt.id);
    batchList('tickets',       _tickets,        (t) => t.toMap(), (t) => t.id);
    batchList('billingExtras', _billingExtras,  (be) => be.toMap(), (be) => be.id);
    // Salvar em lotes de 500 (limite do Firestore)
    await batch.commit();
    // Support settings
    final settingsData = _supportSettings.toMap();
    settingsData.remove('id');
    await _db.collection('settings').doc('support').set(settingsData);
  }

  void _seedPackageTypes() {
    final now = DateTime.now();
    _packageTypes = [
      PackageType(id: 'pkg-pequeno', name: 'Caixa Pequena', description: 'Caixa para pedidos pequenos',
        maxWeightKg: 2, maxLengthCm: 30, maxWidthCm: 20, maxHeightCm: 15, createdAt: now),
      PackageType(id: 'pkg-medio', name: 'Caixa Média', description: 'Caixa para pedidos médios',
        maxWeightKg: 5, maxLengthCm: 40, maxWidthCm: 30, maxHeightCm: 25, createdAt: now),
      PackageType(id: 'pkg-grande', name: 'Caixa Grande', description: 'Caixa para pedidos grandes',
        maxWeightKg: 20, maxLengthCm: 60, maxWidthCm: 50, maxHeightCm: 40, createdAt: now),
      PackageType(id: 'pkg-envelope', name: 'Envelope', description: 'Envelope para documentos e itens finos',
        maxWeightKg: 0.5, maxLengthCm: 35, maxWidthCm: 25, maxHeightCm: 2, createdAt: now),
    ];
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

    // Support Agent (atendente de teste)
    _users.add(AppUser(
      id: 'user-agent1', name: 'Ana Atendente', email: 'atendente@fulfillment.com',
      password: '123456', role: UserRole.supportAgent, createdAt: now,
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

    // Warehouse addresses — 20 posições iniciais (A e B, 2 módulos, 2 níveis, 2-3 posições)
    final addrDefs = [
      ('A', '01', '1', '01'), ('A', '01', '1', '02'), ('A', '01', '1', '03'),
      ('A', '01', '2', '01'), ('A', '01', '2', '02'), ('A', '01', '2', '03'),
      ('A', '02', '1', '01'), ('A', '02', '1', '02'),
      ('A', '02', '2', '01'), ('A', '02', '2', '02'),
      ('B', '01', '1', '01'), ('B', '01', '1', '02'), ('B', '01', '1', '03'),
      ('B', '01', '2', '01'), ('B', '01', '2', '02'), ('B', '01', '2', '03'),
      ('B', '02', '1', '01'), ('B', '02', '1', '02'),
      ('B', '02', '2', '01'), ('B', '02', '2', '02'),
    ];
    for (final (s, m, l, p) in addrDefs) {
      _addresses.add(WarehouseAddress(
        id: 'addr-$s$m$l$p',
        street: s, module: m, level: l, position: p,
      ));
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

    // Support chat tickets — dados de teste para o admin visualizar conversas
    final t1 = SupportTicket(
      id: 'ticket-demo-1',
      clientId: 'client-1',
      clientName: 'TechStore LTDA',
      createdByUserId: 'user-c1',
      createdByUserName: 'Carlos Silva',
      status: TicketStatus.inProgress,
      category: TicketCategory.general,
      subject: 'Chat com suporte',
      assignedToUserId: 'user-admin',
      assignedToUserName: 'Administrador',
      createdAt: now.subtract(const Duration(hours: 3)),
      updatedAt: now.subtract(const Duration(minutes: 30)),
      messages: [
        TicketMessage(
          id: 'msg-d1-1', senderId: 'user-c1', senderName: 'Carlos Silva',
          senderRole: UserRole.client,
          text: 'Olá! Gostaria de saber o status do meu pedido NFV-5001.',
          sentAt: now.subtract(const Duration(hours: 3)),
        ),
        TicketMessage(
          id: 'msg-d1-2', senderId: 'user-admin', senderName: 'Administrador',
          senderRole: UserRole.admin,
          text: 'Olá Carlos! Seu pedido NFV-5001 está em separação. Deve ficar pronto ainda hoje.',
          sentAt: now.subtract(const Duration(hours: 2, minutes: 45)),
        ),
        TicketMessage(
          id: 'msg-d1-3', senderId: 'user-c1', senderName: 'Carlos Silva',
          senderRole: UserRole.client,
          text: 'Ótimo, obrigado! Quando será enviado?',
          sentAt: now.subtract(const Duration(minutes: 30)),
        ),
      ],
    );

    final t2 = SupportTicket(
      id: 'ticket-demo-2',
      clientId: 'client-2',
      clientName: 'ModaFlex S/A',
      createdByUserId: 'user-c2',
      createdByUserName: 'Ana Beatriz',
      status: TicketStatus.open,
      category: TicketCategory.billing,
      subject: 'Chat com suporte',
      createdAt: now.subtract(const Duration(hours: 1)),
      updatedAt: now.subtract(const Duration(minutes: 10)),
      messages: [
        TicketMessage(
          id: 'msg-d2-1', senderId: 'user-c2', senderName: 'Ana Beatriz',
          senderRole: UserRole.client,
          text: 'Boa tarde! Tenho uma dúvida sobre a fatura do mês.',
          sentAt: now.subtract(const Duration(hours: 1)),
        ),
        TicketMessage(
          id: 'msg-d2-2', senderId: 'user-c2', senderName: 'Ana Beatriz',
          senderRole: UserRole.client,
          text: 'O valor cobrado parece diferente do contrato. Podem verificar?',
          sentAt: now.subtract(const Duration(minutes: 10)),
        ),
      ],
    );

    _tickets.addAll([t1, t2]);

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
    // Se ainda inicializando, aguarda os dados chegarem (máx 15s)
    if (_initializing) {
      try {
        await (_usersReadyCompleter?.future ??
            Future.delayed(const Duration(seconds: 2)))
            .timeout(const Duration(seconds: 15));
      } catch (_) {
        // Timeout: tenta mesmo assim com o que tiver
      }
    }
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
    await _saveCollection('clients', _clients, (c) => c.toMap(), (c) => c.id);
    notifyListeners();
  }

  Future<void> updateClient(Client client) async {
    final idx = _clients.indexWhere((c) => c.id == client.id);
    if (idx >= 0) {
      _clients[idx] = client;
      await _saveCollection('clients', _clients, (c) => c.toMap(), (c) => c.id);
      notifyListeners();
    }
  }

  Future<bool> deleteClient(String clientId) async {
    // Verifica se tem pedidos ativos ou lotes
    final hasActiveOrders = _orders.any((o) =>
      o.clientId == clientId && o.status != OrderStatus.finalizado);
    if (hasActiveOrders) return false; // não permite exclusão
    await _deleteDoc('clients', clientId);
    _clients.removeWhere((c) => c.id == clientId);
    // Remove produtos e lotes associados (soft: apenas marca inativo)
    for (final p in _products.where((p) => p.clientId == clientId)) {
      p.isActive = false;
    }
    await _saveCollection('clients', _clients, (c) => c.toMap(), (c) => c.id);
    await _saveCollection('products', _products, (p) => p.toMap(), (p) => p.id);
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

  /// Busca produto por EAN ou cProd da NF-e — usado na importação de XML real
  Product? getProductByEanOrCode(String clientId, String ean, String cProd) {
    // 1. Tenta por EAN exato
    if (ean.isNotEmpty && ean != 'SEM GTIN') {
      final byEan = _products.where((p) =>
        p.clientId == clientId && p.ean.isNotEmpty && p.ean == ean).firstOrNull;
      if (byEan != null) return byEan;
    }
    // 2. Tenta por código NF-e (cProd)
    if (cProd.isNotEmpty) {
      final byCode = _products.where((p) =>
        p.clientId == clientId && p.nfeProductCode.isNotEmpty && p.nfeProductCode == cProd).firstOrNull;
      if (byCode != null) return byCode;
    }
    // 3. Fallback: tenta por SKU (compatibilidade)
    if (cProd.isNotEmpty) {
      final bySku = _products.where((p) =>
        p.clientId == clientId && p.sku == cProd).firstOrNull;
      if (bySku != null) return bySku;
    }
    return null;
  }

  Future<void> addProduct(Product product) async {
    _products.add(product);
    await _saveCollection('products', _products, (p) => p.toMap(), (p) => p.id);
    notifyListeners();
  }

  Future<void> updateProduct(Product product) async {
    final idx = _products.indexWhere((p) => p.id == product.id);
    if (idx >= 0) {
      _products[idx] = product;
      await _saveCollection('products', _products, (p) => p.toMap(), (p) => p.id);
      notifyListeners();
    }
  }

  Future<bool> deleteProduct(String productId) async {
    // Verifica se tem lotes ativos com estoque
    final hasActiveLots = _lots.any((l) =>
        l.productId == productId && l.isActive && l.currentQuantity > 0);
    if (hasActiveLots) return false;
    await _deleteDoc('products', productId);
    _products.removeWhere((p) => p.id == productId);
    await _saveCollection('products', _products, (p) => p.toMap(), (p) => p.id);
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
    await _saveCollection('addresses', _addresses, (a) => a.toMap(), (a) => a.id);
    notifyListeners();
  }

  Future<void> updateAddress(WarehouseAddress address) async {
    final idx = _addresses.indexWhere((a) => a.id == address.id);
    if (idx >= 0) {
      _addresses[idx] = address;
      await _saveCollection('addresses', _addresses, (a) => a.toMap(), (a) => a.id);
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

  /// Ajuste manual de quantidade de um lote (admin).
  /// [delta] pode ser positivo (entrada) ou negativo (retirada).
  Future<String?> adjustLotQuantity(String lotId, int delta, String reason) async {
    final idx = _lots.indexWhere((l) => l.id == lotId);
    if (idx < 0) return 'Lote não encontrado';
    final lot = _lots[idx];
    final newQty = lot.currentQuantity + delta;
    if (newQty < 0) return 'Quantidade insuficiente (atual: ${lot.currentQuantity})';

    _lots[idx].currentQuantity = newQty;
    _lots[idx].movements.add(LotMovement(
      type: delta >= 0 ? 'ajuste_entrada' : 'ajuste_saida',
      quantity: delta.abs(),
      date: DateTime.now(),
      reference: 'ajuste-manual',
      description: 'Ajuste manual: ${delta >= 0 ? '+$delta' : '$delta'} — $reason',
    ));

    // Se ficou zerado, desativa; se voltou a ter estoque, reativa
    if (newQty <= 0) {
      _lots[idx].isActive = false;
    } else {
      _lots[idx].isActive = true;
      // Garante que o endereço está marcado como ocupado
      final addrIdx = _addresses.indexWhere((a) => a.id == lot.addressId);
      if (addrIdx >= 0) {
        _addresses[addrIdx].isOccupied = true;
        _addresses[addrIdx].currentLotId = lot.id;
      }
    }

    await _saveAll();
    notifyListeners();
    return null; // null = sucesso
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

  /// Muda o endereço de armazenamento de um lote (somente admin).
  /// Libera o endereço antigo, ocupa o novo e atualiza o lote.
  Future<String?> moveLot(String lotId, String newAddressId) async {
    final lotIdx = _lots.indexWhere((l) => l.id == lotId);
    if (lotIdx < 0) return 'Lote não encontrado';

    final newAddr = _addresses.where((a) => a.id == newAddressId).firstOrNull;
    if (newAddr == null) return 'Endereço não encontrado';
    if (newAddr.isOccupied && newAddr.currentLotId != lotId) {
      return 'Endereço já está ocupado por outro lote';
    }

    final lot = _lots[lotIdx];

    // Libera o endereço antigo
    final oldAddrIdx = _addresses.indexWhere((a) => a.id == lot.addressId);
    if (oldAddrIdx >= 0) {
      _addresses[oldAddrIdx].isOccupied = false;
      _addresses[oldAddrIdx].currentLotId = null;
    }

    // Ocupa o novo endereço
    final newAddrIdx = _addresses.indexWhere((a) => a.id == newAddressId);
    _addresses[newAddrIdx].isOccupied = true;
    _addresses[newAddrIdx].currentLotId = lotId;

    // Atualiza o lote
    lot.addressId   = newAddr.id;
    lot.addressCode = newAddr.code;

    await _saveAll();
    notifyListeners();
    return null; // null = sucesso
  }

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
    String accessKey = '',
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
          if (product.orderSize == OrderSize.grande) {
            size = OrderSize.grande;
          } else if (product.orderSize == OrderSize.medio && size == OrderSize.pequeno) { size = OrderSize.medio; }
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
      accessKey: accessKey,
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
    await _saveCollection('orders', _orders, (o) => o.toMap(), (o) => o.id);

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

      await _saveCollection('orders', _orders, (o) => o.toMap(), (o) => o.id);

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
    await _saveCollection('orders', _orders, (o) => o.toMap(), (o) => o.id);
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
    await _saveCollection('receivings', _receivings, (r) => r.toMap(), (r) => r.id);
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
    await _saveCollection('users', _users, (u) => u.toMap(), (u) => u.id);
    notifyListeners();
  }

  Future<void> updateUser(AppUser user) async {
    final idx = _users.indexWhere((u) => u.id == user.id);
    if (idx >= 0) {
      _users[idx] = user;
      await _saveCollection('users', _users, (u) => u.toMap(), (u) => u.id);
      notifyListeners();
    }
  }

  Future<bool> deleteUser(String userId) async {
    if (userId == 'user-admin') return false; // protege o admin principal
    await _deleteDoc('users', userId);
    _users.removeWhere((u) => u.id == userId);
    await _saveCollection('users', _users, (u) => u.toMap(), (u) => u.id);
    notifyListeners();
    return true;
  }

  bool emailExists(String email, {String? excludeId}) {
    return _users.any((u) => u.email.toLowerCase() == email.toLowerCase() && u.id != excludeId);
  }

  String newUserId() => 'user-${_uuid.v4().substring(0, 8)}';

  /// Altera a senha do usuário logado atualmente.
  Future<void> changePassword(String newPassword) async {
    if (_currentUser == null) return;
    final updated = _currentUser!.copyWith(password: newPassword);
    await updateUser(updated);
    _currentUser = updated;
    notifyListeners();
  }

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
    await _saveCollection('notifications', _notifications, (n) => n.toMap(), (n) => n.id);
    notifyListeners();
  }

  Future<void> markNotificationRead(String notificationId) async {
    final idx = _notifications.indexWhere((n) => n.id == notificationId);
    if (idx >= 0) {
      _notifications[idx].isRead = true;
      await _saveCollection('notifications', _notifications, (n) => n.toMap(), (n) => n.id);
      notifyListeners();
    }
  }

  Future<void> markAllNotificationsRead(String userId) async {
    for (final n in _notifications.where((n) => n.targetUserId == userId)) {
      n.isRead = true;
    }
    await _saveCollection('notifications', _notifications, (n) => n.toMap(), (n) => n.id);
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
    await _saveCollection('notifications', _notifications, (n) => n.toMap(), (n) => n.id);
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
    await _saveCollection('notifications', _notifications, (n) => n.toMap(), (n) => n.id);
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
      if (o.size == OrderSize.pequeno) {
        small++;
      } else if (o.size == OrderSize.medio) {
        medium++;
      } else if (o.size == OrderSize.envelope) {
        envelope++;
      } else {
        large++;
      }
    }

    final calc = small * client.priceSmallOrder +
        medium * client.priceMediumOrder +
        large * client.priceLargeOrder +
        envelope * client.priceEnvelopeOrder;

    // Include billing extras (additional charges and discounts)
    final extras = getBillingExtras(clientId, year, month);
    final extraTotal = extras.fold(0.0, (s, e) => s + e.value);

    final baseValue = calc + extraTotal;
    final final_ = baseValue < client.minimumMonthly ? client.minimumMonthly : baseValue;

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
    await _saveCollection('billings', _billings, (b) => b.toMap(), (b) => b.id);
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

  // ── XML NF-e parsing (real) ────────────────────────────────────────────────

  /// Resultado de parse de um único XML de NF-e
  static NfeParseResult parseNfeXml(String xmlContent) {
    try {
      final items = <NfeItem>[];
      String invoiceNumber = '';
      String accessKey = '';
      String clientCnpj = '';
      String clientName = '';

      // Número da NF
      final nNFMatch = RegExp(r'<nNF>(\d+)</nNF>').firstMatch(xmlContent);
      if (nNFMatch != null) invoiceNumber = nNFMatch.group(1) ?? '';

      // Chave de acesso — atributo Id da tag infNFe (44 dígitos após "NFe")
      // Formato: Id="NFe35240312345678000100550010000123451234567890"
      final idMatch = RegExp(r'Id="NFe(\d{44})"').firstMatch(xmlContent);
      if (idMatch != null) {
        accessKey = idMatch.group(1) ?? '';
      } else {
        // Fallback: tag <chNFe> no protocolo
        final chMatch = RegExp(r'<chNFe>(\d{44})</chNFe>').firstMatch(xmlContent);
        if (chMatch != null) accessKey = chMatch.group(1) ?? '';
      }

      // CNPJ/CPF destinatário
      final destCnpjMatch = RegExp(r'<dest>.*?<CNPJ>(\d+)</CNPJ>', dotAll: true).firstMatch(xmlContent);
      final destCpfMatch  = RegExp(r'<dest>.*?<CPF>(\d+)</CPF>',  dotAll: true).firstMatch(xmlContent);
      if (destCnpjMatch != null) clientCnpj = destCnpjMatch.group(1) ?? '';
      if (destCpfMatch  != null) clientCnpj = destCpfMatch.group(1)  ?? '';

      // Nome destinatário
      final xNomeMatch = RegExp(r'<dest>.*?<xNome>(.*?)</xNome>', dotAll: true).firstMatch(xmlContent);
      if (xNomeMatch != null) clientName = xNomeMatch.group(1) ?? '';

      // Itens <det>
      final detRegex = RegExp(r'<det[^>]*>(.*?)</det>', dotAll: true);
      for (final det in detRegex.allMatches(xmlContent)) {
        final block = det.group(1) ?? '';
        final cProd  = RegExp(r'<cProd>(.*?)</cProd>').firstMatch(block)?.group(1)?.trim() ?? '';
        final cEAN   = RegExp(r'<cEAN>(.*?)</cEAN>').firstMatch(block)?.group(1)?.trim() ?? '';
        final xProd  = RegExp(r'<xProd>(.*?)</xProd>').firstMatch(block)?.group(1)?.trim() ?? 'Produto';
        final qCom   = double.tryParse(
            RegExp(r'<qCom>(.*?)</qCom>').firstMatch(block)?.group(1) ?? '1') ?? 1.0;
        items.add(NfeItem(
          cProd: cProd,
          cEAN: cEAN == 'SEM GTIN' ? '' : cEAN,
          xProd: xProd,
          quantity: qCom.ceil(),
        ));
      }

      return NfeParseResult(
        invoiceNumber: invoiceNumber,
        accessKey: accessKey,
        clientCnpj: clientCnpj,
        clientName: clientName,
        items: items,
        rawXml: xmlContent,
      );
    } catch (e) {
      return NfeParseResult(
        invoiceNumber: '', accessKey: '', clientCnpj: '', clientName: '',
        items: [], rawXml: xmlContent,
        error: 'Erro ao ler XML: $e',
      );
    }
  }

  // XML parsing simulation (mantido para compatibilidade)
  List<Map<String, dynamic>> parseInvoiceXml(String xmlContent) {
    try {
      final items = <Map<String, dynamic>>[];
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
    // Inclui também eventos de pedidos arquivados
    for (final order in _archivedOrders) {
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

  // ═══════════════════════════════════════════════════════════════════════════
  // ─── GERENCIAMENTO DE ARMAZENAMENTO ────────────────────────────────────────
  // ═══════════════════════════════════════════════════════════════════════════

  List<Order> _archivedOrders = [];
  List<Order> get archivedOrders => List.unmodifiable(_archivedOrders);

  // Regras de retenção (configuráveis)
  static const int _orderArchiveDays       = 90;   // Arquivar pedidos finalizados após X dias
  static const int _archivedOrderDeleteDays = 365; // Excluir arquivados após X dias
  static const int _movementCompactDays    = 60;   // Compactar movimentações antigas após X dias
  static const int _notificationDeleteDays = 30;   // Excluir notificações lidas após X dias
  static const int _orphanLotDays          = 30;   // Lotes zerados sem atividade após X dias
  static const int _maxEventsPerOrder      = 20;   // Máximo de eventos por pedido

  /// Calcula estatísticas de uso do armazenamento.
  StorageStats getStorageStats() {
    final now = DateTime.now();

    // Pedidos prontos para arquivar
    final ordersToArchive = _orders.where((o) {
      final isFinal = o.status == OrderStatus.finalizado || o.status == OrderStatus.enviado;
      final isOld = now.difference(o.updatedAt ?? o.createdAt).inDays >= _orderArchiveDays;
      return isFinal && isOld;
    }).length;

    // Arquivados prontos para excluir
    final archivesToDelete = _archivedOrders.where((o) {
      final archivedAt = o.updatedAt ?? o.createdAt;
      return now.difference(archivedAt).inDays >= _archivedOrderDeleteDays;
    }).length;

    // Movimentações antigas (soma de todas as listas de movements)
    int totalOldMovements = 0;
    for (final lot in _lots) {
      totalOldMovements += lot.movements.where((m) =>
        now.difference(m.date).inDays >= _movementCompactDays
      ).length;
    }

    // Notificações lidas antigas
    final oldNotifications = _notifications.where((n) =>
      n.isRead && now.difference(n.createdAt).inDays >= _notificationDeleteDays
    ).length;

    // Lotes órfãos (zerados sem atividade)
    final orphanLots = _lots.where((l) {
      if (l.currentQuantity > 0) return false;
      final lastActivity = l.movements.isNotEmpty
          ? l.movements.map((m) => m.date).reduce((a, b) => a.isAfter(b) ? a : b)
          : l.receivedAt;
      return now.difference(lastActivity).inDays >= _orphanLotDays;
    }).length;

    // Tamanho estimado (bytes) — cada registro ≈ 500 bytes média
    final estimatedBytes =
        (_orders.length * 800) +
        (_archivedOrders.length * 400) +
        (_lots.length * 600) +
        (_notifications.length * 200) +
        (_receivings.length * 300);

    return StorageStats(
      activeOrders: _orders.length,
      archivedOrders: _archivedOrders.length,
      activeLots: _lots.length,
      totalMovements: _lots.fold(0, (sum, l) => sum + l.movements.length),
      totalNotifications: _notifications.length,
      totalReceivings: _receivings.length,
      ordersToArchive: ordersToArchive,
      archivesToDelete: archivesToDelete,
      oldMovementsToCompact: totalOldMovements,
      oldNotificationsToDelete: oldNotifications,
      orphanLotsToClean: orphanLots,
      estimatedStorageBytes: estimatedBytes,
      lastCleanupAt: null != null
          ? null // last_cleanup_at migrado para Firestore
          : null,
    );
  }

  /// Executa limpeza completa e retorna relatório do que foi feito.
  Future<CleanupReport> runCleanup({bool dryRun = false}) async {
    final now = DateTime.now();
    int archivedCount = 0;
    int deletedArchivesCount = 0;
    int compactedMovements = 0;
    int deletedNotifications = 0;
    int cleanedOrphanLots = 0;
    int trimmedEvents = 0;

    // ── 1. Arquivar pedidos finalizados/cancelados antigos ─────────────────
    final toArchive = _orders.where((o) {
      final isFinal = o.status == OrderStatus.finalizado || o.status == OrderStatus.enviado;
      final isOld = now.difference(o.updatedAt ?? o.createdAt).inDays >= _orderArchiveDays;
      return isFinal && isOld;
    }).toList();

    if (!dryRun) {
      for (final order in toArchive) {
        _orders.remove(order);
        _archivedOrders.add(order);
      }
    }
    archivedCount = toArchive.length;

    // ── 2. Excluir arquivados muito antigos ────────────────────────────────
    final toDeleteArchive = _archivedOrders.where((o) {
      final archivedAt = o.updatedAt ?? o.createdAt;
      return now.difference(archivedAt).inDays >= _archivedOrderDeleteDays;
    }).toList();

    if (!dryRun) {
      for (final order in toDeleteArchive) {
        _archivedOrders.remove(order);
      }
    }
    deletedArchivesCount = toDeleteArchive.length;

    // ── 3. Compactar movimentações antigas dos lotes ───────────────────────
    if (!dryRun) {
      for (final lot in _lots) {
        final recent = <LotMovement>[];
        final oldOnes = <LotMovement>[];

        for (final m in lot.movements) {
          if (now.difference(m.date).inDays >= _movementCompactDays) {
            oldOnes.add(m);
          } else {
            recent.add(m);
          }
        }

        if (oldOnes.isNotEmpty) {
          compactedMovements += oldOnes.length;
          final summary = _compactMovements(oldOnes);
          lot.movements
            ..clear()
            ..addAll([...summary, ...recent]);
        }
      }
    } else {
      for (final lot in _lots) {
        compactedMovements += lot.movements
            .where((m) => now.difference(m.date).inDays >= _movementCompactDays)
            .length;
      }
    }

    // ── 4. Excluir notificações lidas antigas ──────────────────────────────
    final oldNotifs = _notifications.where((n) =>
      n.isRead && now.difference(n.createdAt).inDays >= _notificationDeleteDays
    ).toList();

    if (!dryRun) {
      for (final n in oldNotifs) {
        _notifications.remove(n);
      }
    }
    deletedNotifications = oldNotifs.length;

    // ── 5. Limpar lotes órfãos (zerados sem atividade recente) ─────────────
    final orphanLots = _lots.where((l) {
      if (l.currentQuantity > 0) return false;
      final lastActivity = l.movements.isNotEmpty
          ? l.movements.map((m) => m.date).reduce((a, b) => a.isAfter(b) ? a : b)
          : l.receivedAt;
      return now.difference(lastActivity).inDays >= _orphanLotDays;
    }).toList();

    if (!dryRun) {
      for (final lot in orphanLots) {
        // Libera endereço se ainda vinculado
        final addrIdx = _addresses.indexWhere((a) => a.id == lot.addressId);
        if (addrIdx >= 0 && _addresses[addrIdx].currentLotId == lot.id) {
          _addresses[addrIdx] = WarehouseAddress(
            id: _addresses[addrIdx].id,
            street: _addresses[addrIdx].street,
            module: _addresses[addrIdx].module,
            level: _addresses[addrIdx].level,
            position: _addresses[addrIdx].position,
            isOccupied: false,
            currentLotId: null,
          );
        }
        _lots.remove(lot);
      }
    }
    cleanedOrphanLots = orphanLots.length;

    // ── 6. Aparar eventos excedentes por pedido ────────────────────────────
    if (!dryRun) {
      for (int i = 0; i < _orders.length; i++) {
        final order = _orders[i];
        if (order.events.length > _maxEventsPerOrder) {
          final trimmed = order.events.length - _maxEventsPerOrder;
          trimmedEvents += trimmed;
          // Manter os mais recentes
          order.events
            ..sort((a, b) => b.date.compareTo(a.date))
            ..removeRange(_maxEventsPerOrder, order.events.length);
        }
      }
    }

    // ── Salvar e notificar ─────────────────────────────────────────────────
    if (!dryRun) {
      await _db.collection('settings').doc('cleanup').set({'lastCleanupAt': now.toIso8601String()});
      await _saveCollection('orders', _orders, (o) => o.toMap(), (o) => o.id);
      await _saveCollection('archivedOrders', _archivedOrders, (o) => o.toMap(), (o) => o.id);
      await _saveCollection('lots', _lots, (l) => l.toMap(), (l) => l.id);
      await _saveCollection('addresses', _addresses, (a) => a.toMap(), (a) => a.id);
      await _saveCollection('notifications', _notifications, (n) => n.toMap(), (n) => n.id);
      notifyListeners();
    }

    return CleanupReport(
      archivedOrders: archivedCount,
      deletedArchives: deletedArchivesCount,
      compactedMovements: compactedMovements,
      deletedNotifications: deletedNotifications,
      cleanedOrphanLots: cleanedOrphanLots,
      trimmedEvents: trimmedEvents,
      executedAt: now,
      isDryRun: dryRun,
    );
  }

  /// Agrupa movimentações antigas em resumos por tipo.
  List<LotMovement> _compactMovements(List<LotMovement> old) {
    if (old.isEmpty) return [];

    final groups = <String, List<LotMovement>>{};
    for (final m in old) {
      groups.putIfAbsent(m.type, () => []).add(m);
    }

    final result = <LotMovement>[];
    groups.forEach((type, movements) {
      final total = movements.fold(0, (sum, m) => sum + m.quantity);
      final earliest = movements.map((m) => m.date).reduce((a, b) => a.isBefore(b) ? a : b);
      final latest   = movements.map((m) => m.date).reduce((a, b) => a.isAfter(b) ? a : b);
      final label = switch (type) {
        'entrada'       => 'Entradas',
        'saida'         => 'Saídas',
        'ajuste_entrada'=> 'Ajustes +',
        'ajuste_saida'  => 'Ajustes −',
        _               => type,
      };
      result.add(LotMovement(
        type: type,
        quantity: total,
        date: latest,
        reference: 'compactado',
        description: '[$label compactadas: ${movements.length} registros, '
            'total $total un. — '
            '${_fmtDate(earliest)} a ${_fmtDate(latest)}]',
      ));
    });
    return result;
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  /// Inicializa carregando também os arquivados.
  Future<void> _loadArchived() async {
    // _archivedOrders carregado pelo _loadAll via Firestore
  }

  /// Busca pedido por ID, incluindo arquivados.
  Order? findOrderById(String id) {
    try {
      return _orders.firstWhere((o) => o.id == id);
    } catch (_) {
      try {
        return _archivedOrders.firstWhere((o) => o.id == id);
      } catch (_) {
        return null;
      }
    }
  }

  /// Restaura um pedido arquivado de volta para ativo.
  Future<void> restoreArchivedOrder(String orderId) async {
    final idx = _archivedOrders.indexWhere((o) => o.id == orderId);
    if (idx < 0) return;
    final order = _archivedOrders.removeAt(idx);
    _orders.add(order);
    await _saveCollection('orders', _orders, (o) => o.toMap(), (o) => o.id);
    await _saveCollection('archivedOrders', _archivedOrders, (o) => o.toMap(), (o) => o.id);
    notifyListeners();
  }

  // ─── PACKAGE TYPES ───────────────────────────────────────────────────────

  List<PackageType> get packageTypes => List.unmodifiable(_packageTypes.where((p) => p.isActive).toList());
  List<PackageType> get allPackageTypes => List.unmodifiable(_packageTypes);

  Future<void> addPackageType(PackageType pt) async {
    _packageTypes.add(pt);
    await _saveCollection('packageTypes', _packageTypes, (pt) => pt.toMap(), (pt) => pt.id);
    notifyListeners();
  }

  Future<void> updatePackageType(PackageType pt) async {
    final idx = _packageTypes.indexWhere((p) => p.id == pt.id);
    if (idx >= 0) {
      _packageTypes[idx] = pt;
      await _saveCollection('packageTypes', _packageTypes, (pt) => pt.toMap(), (pt) => pt.id);
      notifyListeners();
    }
  }

  Future<void> deletePackageType(String id) async {
    await _deleteDoc('packageTypes', id);
    _packageTypes.removeWhere((p) => p.id == id);
    await _saveCollection('packageTypes', _packageTypes, (pt) => pt.toMap(), (pt) => pt.id);
    notifyListeners();
  }

  String newPackageTypeId() => 'pkg-${_uuid.v4().substring(0, 8)}';

  // ─── SUPPORT TICKETS ─────────────────────────────────────────────────────

  List<SupportTicket> get allTickets => List.unmodifiable(_tickets);

  List<SupportTicket> getTicketsForClient(String clientId) =>
      _tickets.where((t) => t.clientId == clientId).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  List<SupportTicket> get openTickets => _tickets
      .where((t) => t.status.isActive).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  SupportTicket? getTicket(String id) => _tickets.where((t) => t.id == id).firstOrNull;

  Future<SupportTicket> createTicket({
    required String clientId,
    required String clientName,
    required String createdByUserId,
    required String createdByUserName,
    required TicketCategory category,
    required String subject,
    String? firstMessage,
    String? relatedOrderId,
    String? relatedOrderInvoice,
    bool isReturnRequest = false,
    bool createdByStaff = false,
  }) async {
    final now = DateTime.now();
    final ticket = SupportTicket(
      id: 'ticket-${_uuid.v4().substring(0, 8)}',
      clientId: clientId,
      clientName: clientName,
      createdByUserId: createdByUserId,
      createdByUserName: createdByUserName,
      category: category,
      subject: subject,
      relatedOrderId: relatedOrderId,
      relatedOrderInvoice: relatedOrderInvoice,
      isReturnRequest: isReturnRequest,
      createdAt: now,
      createdByStaff: createdByStaff,
    );

    if (createdByStaff) {
      // Chamado interno: aguarda aprovação do admin, sem auto-atribuição,
      // sem mensagens automáticas. Status = open.
      ticket.status = TicketStatus.open;
      // Registrar quem abriu
      ticket.assignedToUserId = createdByUserId;
      ticket.assignedToUserName = createdByUserName;
    } else {
      // Chat do cliente: auto-assign + mensagens automáticas
      final supporter = _users.firstWhere(
        (u) => (u.role == UserRole.supportAgent ||
                u.role == UserRole.operator ||
                u.role == UserRole.admin) &&
            u.isActive,
        orElse: () => _users.first,
      );
      ticket.assignedToUserId = supporter.id;
      ticket.assignedToUserName = supporter.name;
      ticket.status = TicketStatus.inProgress;

      // Add first message
      if (firstMessage != null && firstMessage.isNotEmpty) {
        ticket.messages.add(TicketMessage(
          id: _uuid.v4(),
          senderId: createdByUserId,
          senderName: createdByUserName,
          senderRole: _users
              .firstWhere((u) => u.id == createdByUserId,
                  orElse: () => _users.first)
              .role,
          text: firstMessage,
          sentAt: now,
        ));
      }

      // Mensagem automática: somente quando o atendimento está desligado (isOnline=false)
      // Horário de funcionamento NÃO interfere mais — só o botão online/offline
      final settings = _supportSettings;
      final autoMsg = settings.isOnline
          ? settings.waitMessage
          : settings.offlineMessage;
      ticket.messages.add(TicketMessage(
        id: _uuid.v4(),
        senderId: 'system',
        senderName: 'Sistema',
        senderRole: UserRole.admin,
        text: autoMsg,
        sentAt: now.add(const Duration(seconds: 1)),
        isSystem: true,
      ));
    }

    _tickets.add(ticket);
    await _saveCollection('tickets', _tickets, (t) => t.toMap(), (t) => t.id);
    notifyListeners();
    return ticket;
  }

  Future<void> sendTicketMessage({
    required String ticketId,
    required String senderId,
    required String senderName,
    required UserRole senderRole,
    required String text,
    String? attachmentUrl,
    String? attachmentName,
    String? attachmentType,
  }) async {
    final idx = _tickets.indexWhere((t) => t.id == ticketId);
    if (idx < 0) return;
    final ticket = _tickets[idx];
    ticket.messages.add(TicketMessage(
      id: _uuid.v4(),
      senderId: senderId,
      senderName: senderName,
      senderRole: senderRole,
      text: text,
      sentAt: DateTime.now(),
      attachmentUrl: attachmentUrl,
      attachmentName: attachmentName,
      attachmentType: attachmentType,
    ));
    ticket.updatedAt = DateTime.now();
    // If client responds and ticket was pending client, back to in progress
    if (senderRole == UserRole.client && ticket.status == TicketStatus.pendingClient) {
      ticket.status = TicketStatus.inProgress;
    }
    await _saveCollection('tickets', _tickets, (t) => t.toMap(), (t) => t.id);
    notifyListeners();
  }

  Future<void> assignTicket(String ticketId, String userId, String userName) async {
    final idx = _tickets.indexWhere((t) => t.id == ticketId);
    if (idx < 0) return;
    _tickets[idx].assignedToUserId = userId;
    _tickets[idx].assignedToUserName = userName;
    _tickets[idx].updatedAt = DateTime.now();
    await _saveCollection('tickets', _tickets, (t) => t.toMap(), (t) => t.id);
    notifyListeners();
  }

  Future<void> updateTicketStatus(String ticketId, TicketStatus status) async {
    final idx = _tickets.indexWhere((t) => t.id == ticketId);
    if (idx < 0) return;
    _tickets[idx].status = status;
    _tickets[idx].updatedAt = DateTime.now();
    if (status == TicketStatus.resolved || status == TicketStatus.closed) {
      _tickets[idx].resolvedAt = DateTime.now();
    }
    await _saveCollection('tickets', _tickets, (t) => t.toMap(), (t) => t.id);
    notifyListeners();
  }

  /// Funcionário aceita um chat (status → inProgress, assigned ao agente)
  Future<void> acceptChat(String ticketId) async {
    if (_currentUser == null) return;
    final idx = _tickets.indexWhere((t) => t.id == ticketId);
    if (idx < 0) return;
    _tickets[idx].assignedToUserId = _currentUser!.id;
    _tickets[idx].assignedToUserName = _currentUser!.name;
    _tickets[idx].status = TicketStatus.inProgress;
    _tickets[idx].startedAt = DateTime.now();   // marca início do atendimento
    _tickets[idx].updatedAt = DateTime.now();
    await _saveCollection('tickets', _tickets, (t) => t.toMap(), (t) => t.id);
    notifyListeners();
  }

  /// Encerra atendimento: status → resolved, cliente pode avaliar
  Future<void> closeChat(String ticketId) async {
    final idx = _tickets.indexWhere((t) => t.id == ticketId);
    if (idx < 0) return;
    _tickets[idx].status = TicketStatus.resolved;
    _tickets[idx].resolvedAt = DateTime.now();
    _tickets[idx].updatedAt = DateTime.now();
    // Adiciona mensagem de sistema
    _tickets[idx].messages.add(TicketMessage(
      id: 'close-${DateTime.now().millisecondsSinceEpoch}',
      senderId: 'system',
      senderName: 'Sistema',
      senderRole: UserRole.admin,
      text: 'Atendimento encerrado. Por favor, avalie o atendimento recebido.',
      sentAt: DateTime.now(),
      isSystem: true,
    ));
    await _saveCollection('tickets', _tickets, (t) => t.toMap(), (t) => t.id);
    notifyListeners();
  }

  /// Atualiza observações internas do funcionário no chamado
  Future<void> updateTicketNotes(String ticketId, String notes) async {
    final idx = _tickets.indexWhere((t) => t.id == ticketId);
    if (idx < 0) return;
    _tickets[idx].agentNotes = notes;
    _tickets[idx].updatedAt = DateTime.now();
    await _saveCollection('tickets', _tickets, (t) => t.toMap(), (t) => t.id);
    notifyListeners();
  }

  /// Salva dados extras de devolução e persiste
  Future<void> updateTicketReturnData(
      String ticketId, int qty, String? invoice) async {
    final idx = _tickets.indexWhere((t) => t.id == ticketId);
    if (idx < 0) return;
    _tickets[idx].returnQuantity = qty;
    _tickets[idx].returnOrderInvoice = invoice;
    _tickets[idx].updatedAt = DateTime.now();
    await _saveCollection('tickets', _tickets, (t) => t.toMap(), (t) => t.id);
    notifyListeners();
  }

  /// Admin aprova um chamado
  Future<void> approveTicket(String ticketId, {String? note}) async {
    final idx = _tickets.indexWhere((t) => t.id == ticketId);
    if (idx < 0) return;
    _tickets[idx].adminApproved = true;
    _tickets[idx].adminRejected = false;
    _tickets[idx].adminApprovalNote = note;
    _tickets[idx].status = TicketStatus.inProgress;
    _tickets[idx].updatedAt = DateTime.now();
    await _saveCollection('tickets', _tickets, (t) => t.toMap(), (t) => t.id);
    notifyListeners();
  }

  /// Admin recusa um chamado
  Future<void> rejectTicket(String ticketId, {required String reason}) async {
    final idx = _tickets.indexWhere((t) => t.id == ticketId);
    if (idx < 0) return;
    _tickets[idx].adminRejected = true;
    _tickets[idx].adminApproved = false;
    _tickets[idx].adminRejectionNote = reason;
    _tickets[idx].status = TicketStatus.closed;
    _tickets[idx].resolvedAt = DateTime.now();
    _tickets[idx].updatedAt = DateTime.now();
    await _saveCollection('tickets', _tickets, (t) => t.toMap(), (t) => t.id);
    notifyListeners();
  }

  /// Marca como resolvido pelo atendente
  Future<void> resolveTicket(String ticketId) async {
    final idx = _tickets.indexWhere((t) => t.id == ticketId);
    if (idx < 0) return;
    _tickets[idx].status = TicketStatus.resolved;
    _tickets[idx].resolvedAt = DateTime.now();
    _tickets[idx].updatedAt = DateTime.now();
    await _saveCollection('tickets', _tickets, (t) => t.toMap(), (t) => t.id);
    notifyListeners();
  }

  /// Estatísticas por atendente (chats apenas)
  List<Map<String, dynamic>> getAgentStats() {
    // Pega todos os usuários que são atendentes, operadores ou admin
    final staff = _users.where((u) =>
        u.role == UserRole.supportAgent ||
        u.role == UserRole.operator ||
        u.role == UserRole.admin).toList();

    return staff.map((agent) {
      // Tickets que foram atribuídos a este agente (somente chats, não chamados)
      final agentTickets = _tickets.where((t) =>
          t.assignedToUserId == agent.id && !_isTicketChamado(t)).toList();

      final total = agentTickets.length;
      final rated = agentTickets.where((t) => t.rating != null).toList();
      final closed = agentTickets.where((t) =>
          t.status == TicketStatus.resolved ||
          t.status == TicketStatus.closed).toList();

      // Tempo médio em minutos (startedAt → resolvedAt)
      final timesMin = closed
          .where((t) => t.resolvedAt != null && t.startedAt != null)
          .map((t) => t.resolvedAt!.difference(t.startedAt!).inMinutes)
          .toList();
      final avgTime = timesMin.isEmpty
          ? 0.0
          : timesMin.reduce((a, b) => a + b) / timesMin.length;

      // Avaliação média
      final avgRating = rated.isEmpty
          ? 0.0
          : rated.map((t) => t.rating!).reduce((a, b) => a + b) /
              rated.length;

      return {
        'agentId': agent.id,
        'agentName': agent.name,
        'role': agent.role,
        'total': total,
        'closed': closed.length,
        'avgTimeMin': avgTime,
        'avgRating': avgRating,
        'ratingCount': rated.length,
      };
    }).toList();
  }

  /// Estatísticas por atendente filtradas por mês (somente chats)
  List<Map<String, dynamic>> getAgentStatsByMonth(DateTime month) {
    final staff = _users.where((u) =>
        u.role == UserRole.supportAgent ||
        u.role == UserRole.admin).toList();

    final result = <Map<String, dynamic>>[];
    for (final agent in staff) {
      // Chats atribuídos a este agente que foram criados no mês selecionado
      final agentTickets = _tickets.where((t) {
        if (t.assignedToUserId != agent.id) return false;
        if (_isTicketChamado(t)) return false;
        return t.createdAt.year == month.year &&
            t.createdAt.month == month.month;
      }).toList();

      if (agentTickets.isEmpty) continue; // pula agentes sem atendimentos no mês

      final rated = agentTickets.where((t) => t.rating != null).toList();
      final closed = agentTickets.where((t) =>
          t.status == TicketStatus.resolved ||
          t.status == TicketStatus.closed).toList();

      final timesMin = closed
          .where((t) => t.resolvedAt != null && t.startedAt != null)
          .map((t) => t.resolvedAt!.difference(t.startedAt!).inMinutes.toDouble())
          .toList();
      final avgTime = timesMin.isEmpty
          ? 0.0
          : timesMin.reduce((a, b) => a + b) / timesMin.length;

      final avgRating = rated.isEmpty
          ? 0.0
          : rated.map((t) => t.rating!.toDouble()).reduce((a, b) => a + b) /
              rated.length;

      result.add({
        'agentId': agent.id,
        'agentName': agent.name,
        'role': agent.role,
        'total': agentTickets.length,
        'closed': closed.length,
        'avgTimeMin': avgTime,
        'avgRating': avgRating,
        'ratingCount': rated.length,
      });
    }

    // Ordenar por total de atendimentos (maior primeiro)
    result.sort((a, b) => (b['total'] as int).compareTo(a['total'] as int));
    return result;
  }

  /// Remove avaliações e histórico de chats do mês informado
  Future<void> clearMonthStats(DateTime month) async {
    _tickets.removeWhere((t) {
      if (_isTicketChamado(t)) return false;
      if (t.status != TicketStatus.resolved && t.status != TicketStatus.closed) {
        return false;
      }
      return t.createdAt.year == month.year &&
          t.createdAt.month == month.month;
    });
    await _saveCollection('tickets', _tickets, (t) => t.toMap(), (t) => t.id);
    notifyListeners();
  }

  bool _isTicketChamado(SupportTicket t) {
    const chamadoCats = {
      TicketCategory.return_product,
      TicketCategory.damage,
      TicketCategory.complaint,
      TicketCategory.shipping,
      TicketCategory.billing,
      TicketCategory.technical,
      TicketCategory.stock,
    };
    return chamadoCats.contains(t.category);
  }

  /// Retorna avaliações agrupadas por funcionário de suporte
  Map<String, Map<String, dynamic>> getAgentRatings() {
    final result = <String, Map<String, dynamic>>{};
    for (final ticket in _tickets) {
      if (ticket.rating == null || ticket.assignedToUserId == null) continue;
      final agentId = ticket.assignedToUserId!;
      if (!result.containsKey(agentId)) {
        result[agentId] = {
          'name': ticket.assignedToUserName ?? 'Desconhecido',
          'ratings': <int>[],
          'count': 0,
          'avg': 0.0,
        };
      }
      (result[agentId]!['ratings'] as List<int>).add(ticket.rating!);
    }
    // Calcular médias
    for (final key in result.keys) {
      final ratings = result[key]!['ratings'] as List<int>;
      result[key]!['count'] = ratings.length;
      result[key]!['avg'] = ratings.isEmpty
          ? 0.0
          : ratings.reduce((a, b) => a + b) / ratings.length;
    }
    return result;
  }

  /// Chats disponíveis para o funcionário atual aceitar (sem assigned ou assigned a mim)
  List<SupportTicket> getAvailableChats() {
    if (isAdmin) {
      // Admin vê tudo (incluindo encerrados para histórico)
      return _tickets.where((t) => !t.isReturnRequest).toList()
        ..sort((a, b) =>
            (b.updatedAt ?? b.createdAt).compareTo(a.updatedAt ?? a.createdAt));
    }
    if (isSupportAgent || isOperator) {
      // Agente/operador vê: não atribuídos (para aceitar) OU atribuídos a ele
      // Após encerrar (resolved/closed), o ticket some da lista do funcionário
      return _tickets
          .where((t) =>
              !t.isReturnRequest &&
              t.status.isActive &&  // só mostra ativos (open, inProgress, pendingClient)
              (t.assignedToUserId == null ||
                  t.assignedToUserId == _currentUser?.id))
          .toList()
        ..sort((a, b) =>
            (b.updatedAt ?? b.createdAt).compareTo(a.updatedAt ?? a.createdAt));
    }
    return [];
  }

  /// Chamados (tickets de problema) visíveis para o usuário atual
  List<SupportTicket> getVisibleTickets() {
    final chamadoCats = {
      TicketCategory.return_product,
      TicketCategory.damage,
      TicketCategory.complaint,
      TicketCategory.shipping,
      TicketCategory.billing,
      TicketCategory.technical,
      TicketCategory.stock,
    };
    if (isAdmin) {
      return _tickets.where((t) => chamadoCats.contains(t.category)).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
    // Agente/operador: só chamados criados por ele ou atribuídos a ele
    return _tickets
        .where((t) =>
            chamadoCats.contains(t.category) &&
            (t.createdByUserId == _currentUser?.id ||
                t.assignedToUserId == _currentUser?.id))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<void> rateTicket(String ticketId, int rating, {String? comment}) async {
    final idx = _tickets.indexWhere((t) => t.id == ticketId);
    if (idx < 0) return;
    _tickets[idx].rating = rating;
    _tickets[idx].ratingComment = comment;
    _tickets[idx].status = TicketStatus.closed;
    await _saveCollection('tickets', _tickets, (t) => t.toMap(), (t) => t.id);
    notifyListeners();
  }

  Future<void> approveReturnRequest(String ticketId, {required bool approved, required bool returnToStock}) async {
    final idx = _tickets.indexWhere((t) => t.id == ticketId);
    if (idx < 0) return;
    final ticket = _tickets[idx];
    ticket.returnApprovedByAdmin = approved;
    ticket.returnToStock = returnToStock;
    ticket.updatedAt = DateTime.now();
    if (approved) {
      ticket.status = TicketStatus.resolved;
      ticket.resolvedAt = DateTime.now();
      // System message
      ticket.messages.add(TicketMessage(
        id: _uuid.v4(),
        senderId: 'system',
        senderName: 'Sistema',
        senderRole: UserRole.admin,
        text: approved
            ? 'Devolução aprovada pelo administrador. ${returnToStock ? "O item será retornado ao estoque." : "O item não será retornado ao estoque."}'
            : 'Devolução reprovada pelo administrador.',
        sentAt: DateTime.now(),
        isSystem: true,
      ));
    }
    await _saveCollection('tickets', _tickets, (t) => t.toMap(), (t) => t.id);
    notifyListeners();
  }

  // Ticket metrics
  Map<String, dynamic> getTicketMetrics() {
    final now = DateTime.now();
    final resolved = _tickets.where((t) =>
      t.status == TicketStatus.resolved || t.status == TicketStatus.closed).toList();
    final withRating = resolved.where((t) => t.rating != null).toList();
    final avgRating = withRating.isEmpty ? 0.0
        : withRating.fold(0.0, (s, t) => s + t.rating!) / withRating.length;

    // Avg resolution time in hours
    final resolutionTimes = resolved
        .where((t) => t.resolvedAt != null)
        .map((t) => t.resolvedAt!.difference(t.createdAt).inHours)
        .toList();
    final avgResolutionHours = resolutionTimes.isEmpty ? 0.0
        : resolutionTimes.fold(0, (s, h) => s + h) / resolutionTimes.length;

    return {
      'total': _tickets.length,
      'open': _tickets.where((t) => t.status == TicketStatus.open).length,
      'inProgress': _tickets.where((t) => t.status == TicketStatus.inProgress).length,
      'resolved': resolved.length,
      'avgRating': avgRating,
      'avgResolutionHours': avgResolutionHours,
      'thisMonth': _tickets.where((t) =>
        t.createdAt.year == now.year && t.createdAt.month == now.month).length,
      'returnRequests': _tickets.where((t) => t.isReturnRequest).length,
      'pendingReturns': _tickets.where((t) =>
        t.isReturnRequest && t.returnApprovedByAdmin == null).length,
    };
  }

  // ─── SUPPORT SETTINGS ────────────────────────────────────────────────────

  SupportSettings get supportSettings => _supportSettings;

  Future<void> updateSupportSettings(SupportSettings settings) async {
    _supportSettings = settings;
    final sData = settings.toMap(); sData.remove('id'); await _db.collection('settings').doc('support').set(sData);
    notifyListeners();
  }

  // ─── BILLING EXTRAS ──────────────────────────────────────────────────────

  List<BillingExtra> getBillingExtras(String clientId, int year, int month) =>
      _billingExtras.where((e) =>
        e.clientId == clientId && e.year == year && e.month == month).toList();

  Future<void> addBillingExtra(BillingExtra extra) async {
    _billingExtras.add(extra);
    await _saveCollection('billingExtras', _billingExtras, (be) => be.toMap(), (be) => be.id);
    notifyListeners();
  }

  Future<void> deleteBillingExtra(String id) async {
    await _deleteDoc('billingExtras', id);
    _billingExtras.removeWhere((e) => e.id == id);
    await _saveCollection('billingExtras', _billingExtras, (be) => be.toMap(), (be) => be.id);
    notifyListeners();
  }

  String newBillingExtraId() => 'extra-${_uuid.v4().substring(0, 8)}';
  String newTicketId() => 'ticket-${_uuid.v4().substring(0, 8)}';
}
