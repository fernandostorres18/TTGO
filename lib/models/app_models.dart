// lib/models/app_models.dart
// Todos os modelos de dados do sistema Fulfillment Master
import 'package:flutter/material.dart' show Icons, IconData;
import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;

// Helper: converte Timestamp do Firestore OU String ISO para DateTime
DateTime _parseDate(dynamic v) {
  if (v == null) return DateTime.now();
  if (v is Timestamp) return v.toDate();
  if (v is String) return DateTime.parse(v);
  if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
  return DateTime.now();
}

DateTime? _parseDateOrNull(dynamic v) {
  if (v == null) return null;
  if (v is Timestamp) return v.toDate();
  if (v is String) return DateTime.parse(v);
  if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
  return null;
}
import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;

// ─── HELPER: converte Timestamp Firestore OU String para DateTime ──────────
DateTime _parseDate(dynamic v) {
  if (v == null) return DateTime.now();
  if (v is Timestamp) return v.toDate();
  if (v is DateTime) return v;
  if (v is String && v.isNotEmpty) {
    try { return DateTime.parse(v); } catch (_) {}
  }
  return DateTime.now();
}

DateTime? _parseDateNullable(dynamic v) {
  if (v == null) return null;
  if (v is Timestamp) return v.toDate();
  if (v is DateTime) return v;
  if (v is String && v.isNotEmpty) {
    try { return DateTime.parse(v); } catch (_) {}
  }
  return null;
}

// ─── ENUMS ─────────────────────────────────────────────────────────────────

enum UserRole { admin, operator, client, supportAgent }

extension UserRoleExt on UserRole {
  String get label {
    switch (this) {
      case UserRole.admin: return 'Administrador';
      case UserRole.operator: return 'Operador';
      case UserRole.client: return 'Cliente';
      case UserRole.supportAgent: return 'Atendente de Suporte';
    }
  }
  bool get isStaff => this == UserRole.admin || this == UserRole.operator || this == UserRole.supportAgent;
}

enum NotificationType {
  newOrder,       // cliente criou pedido → notifica admin/operador
  stockReceived,  // mercadoria recebida → notifica cliente
  orderStatus,    // status do pedido atualizado → notifica cliente
  lowStock,       // estoque baixo → notifica admin
}

extension NotificationTypeExt on NotificationType {
  String get label {
    switch (this) {
      case NotificationType.newOrder: return 'Novo Pedido';
      case NotificationType.stockReceived: return 'Mercadoria Recebida';
      case NotificationType.orderStatus: return 'Status do Pedido';
      case NotificationType.lowStock: return 'Estoque Baixo';
    }
  }
}

enum OrderStatus {
  recebido,
  aguardandoSeparacao,
  separando,
  faturado,
  enviado,
  finalizado,
}

enum OrderSize { pequeno, medio, grande, envelope }

enum ClientStatus { ativo, inativo }

extension OrderStatusExt on OrderStatus {
  String get label {
    switch (this) {
      case OrderStatus.recebido: return 'Recebido';
      case OrderStatus.aguardandoSeparacao: return 'Ag. Separação';
      case OrderStatus.separando: return 'Separando';
      case OrderStatus.faturado: return 'Faturado';
      case OrderStatus.enviado: return 'Enviado';
      case OrderStatus.finalizado: return 'Finalizado';
    }
  }
  int get index2 => OrderStatus.values.indexOf(this);
}

extension OrderSizeExt on OrderSize {
  String get label {
    switch (this) {
      case OrderSize.pequeno: return 'Pequeno';
      case OrderSize.medio: return 'Médio';
      case OrderSize.grande: return 'Grande';
      case OrderSize.envelope: return 'Envelope';
    }
  }

  IconData get icon {
    switch (this) {
      case OrderSize.pequeno: return Icons.inbox;
      case OrderSize.medio: return Icons.inventory_2;
      case OrderSize.grande: return Icons.all_inbox;
      case OrderSize.envelope: return Icons.mail_outline;
    }
  }
}

// ─── USER ──────────────────────────────────────────────────────────────────

class AppUser {
  final String id;
  final String name;
  final String email;
  final String password; // hashed in real app
  final UserRole role;
  final String? clientId; // only for client role
  final bool isActive;
  final DateTime createdAt;

  AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.password,
    required this.role,
    this.clientId,
    this.isActive = true,
    required this.createdAt,
  });

  AppUser copyWith({
    String? name,
    String? email,
    String? password,
    UserRole? role,
    String? clientId,
    bool? isActive,
  }) {
    return AppUser(
      id: id,
      name: name ?? this.name,
      email: email ?? this.email,
      password: password ?? this.password,
      role: role ?? this.role,
      clientId: clientId ?? this.clientId,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id, 'name': name, 'email': email, 'password': password,
    'role': role.index, 'clientId': clientId, 'isActive': isActive,
    'createdAt': createdAt.toIso8601String(),
  };

  factory AppUser.fromMap(Map<String, dynamic> m) => AppUser(
    id: m['id'], name: m['name'], email: m['email'], password: m['password'],
    role: UserRole.values[m['role'] ?? 0],
    clientId: m['clientId'],
    isActive: m['isActive'] ?? true,
    createdAt: _parseDate(m['createdAt']),
  );
}

// ─── CLIENT ────────────────────────────────────────────────────────────────

class Client {
  final String id;
  String companyName;
  String cnpjCpf;
  String responsibleName;
  String phone;
  String email;
  String contractPlan;
  double minimumMonthly;
  double priceSmallOrder;
  double priceMediumOrder;
  double priceLargeOrder;
  double priceEnvelopeOrder;
  ClientStatus status;
  final DateTime createdAt;
  String? photoUrl; // URL base64 ou URL da foto do cliente

  Client({
    required this.id,
    required this.companyName,
    required this.cnpjCpf,
    required this.responsibleName,
    required this.phone,
    required this.email,
    required this.contractPlan,
    required this.minimumMonthly,
    required this.priceSmallOrder,
    required this.priceMediumOrder,
    required this.priceLargeOrder,
    this.priceEnvelopeOrder = 5,
    this.status = ClientStatus.ativo,
    required this.createdAt,
    this.photoUrl,
  });

  Map<String, dynamic> toMap() => {
    'id': id, 'companyName': companyName, 'cnpjCpf': cnpjCpf,
    'responsibleName': responsibleName, 'phone': phone, 'email': email,
    'contractPlan': contractPlan, 'minimumMonthly': minimumMonthly,
    'priceSmallOrder': priceSmallOrder, 'priceMediumOrder': priceMediumOrder,
    'priceLargeOrder': priceLargeOrder, 'priceEnvelopeOrder': priceEnvelopeOrder,
    'status': status.index,
    'createdAt': createdAt.toIso8601String(),
    'photoUrl': photoUrl,
  };

  factory Client.fromMap(Map<String, dynamic> m) => Client(
    id: m['id'], companyName: m['companyName'], cnpjCpf: m['cnpjCpf'],
    responsibleName: m['responsibleName'], phone: m['phone'], email: m['email'],
    contractPlan: m['contractPlan'],
    minimumMonthly: (m['minimumMonthly'] ?? 0).toDouble(),
    priceSmallOrder: (m['priceSmallOrder'] ?? 0).toDouble(),
    priceMediumOrder: (m['priceMediumOrder'] ?? 0).toDouble(),
    priceLargeOrder: (m['priceLargeOrder'] ?? 0).toDouble(),
    priceEnvelopeOrder: (m['priceEnvelopeOrder'] ?? 5).toDouble(),
    status: ClientStatus.values[m['status'] ?? 0],
    createdAt: _parseDate(m['createdAt']),
    photoUrl: m['photoUrl'],
  );

  String get initials {
    final parts = companyName.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return companyName.substring(0, 2).toUpperCase();
  }
}

// ─── PRODUCT ───────────────────────────────────────────────────────────────

class Product {
  final String id;
  final String clientId;
  String sku;
  String name;
  String ean;            // EAN-13 / GTIN (cEAN na NF-e)
  String nfeProductCode; // Código do produto na NF-e (cProd)
  double weightKg;
  double heightCm;
  double widthCm;
  double lengthCm;
  int minimumStock;
  bool isActive;
  final DateTime createdAt;

  Product({
    required this.id,
    required this.clientId,
    required this.sku,
    required this.name,
    this.ean = '',
    this.nfeProductCode = '',
    required this.weightKg,
    required this.heightCm,
    required this.widthCm,
    required this.lengthCm,
    required this.minimumStock,
    this.isActive = true,
    required this.createdAt,
  });

  // Calculate order size based on dimensions and weight
  OrderSize get orderSize {
    final volume = heightCm * widthCm * lengthCm;
    if (weightKg <= 1.0 && volume <= 1000) return OrderSize.pequeno;
    if (weightKg <= 5.0 && volume <= 10000) return OrderSize.medio;
    return OrderSize.grande;
  }

  Map<String, dynamic> toMap() => {
    'id': id, 'clientId': clientId, 'sku': sku, 'name': name,
    'ean': ean, 'nfeProductCode': nfeProductCode,
    'weightKg': weightKg, 'heightCm': heightCm, 'widthCm': widthCm,
    'lengthCm': lengthCm, 'minimumStock': minimumStock, 'isActive': isActive,
    'createdAt': createdAt.toIso8601String(),
  };

  factory Product.fromMap(Map<String, dynamic> m) => Product(
    id: m['id'], clientId: m['clientId'], sku: m['sku'], name: m['name'],
    ean: m['ean'] ?? '',
    nfeProductCode: m['nfeProductCode'] ?? '',
    weightKg: (m['weightKg'] ?? 0).toDouble(),
    heightCm: (m['heightCm'] ?? 0).toDouble(),
    widthCm: (m['widthCm'] ?? 0).toDouble(),
    lengthCm: (m['lengthCm'] ?? 0).toDouble(),
    minimumStock: m['minimumStock'] ?? 0,
    isActive: m['isActive'] ?? true,
    createdAt: _parseDate(m['createdAt']),
  );
}

// ─── WAREHOUSE ADDRESS ─────────────────────────────────────────────────────

class WarehouseAddress {
  final String id;
  String street;
  String module;
  String level;
  String position;
  bool isOccupied;
  String? currentLotId;

  WarehouseAddress({
    required this.id,
    required this.street,
    required this.module,
    required this.level,
    required this.position,
    this.isOccupied = false,
    this.currentLotId,
  });

  String get code => '$street-$module-$level-$position';
  String get barcode => 'ADDR-$id';
  String get displayName => 'Rua $street / Módulo $module / Nível $level / Pos $position';

  Map<String, dynamic> toMap() => {
    'id': id, 'street': street, 'module': module, 'level': level,
    'position': position, 'isOccupied': isOccupied, 'currentLotId': currentLotId,
  };

  factory WarehouseAddress.fromMap(Map<String, dynamic> m) => WarehouseAddress(
    id: m['id'], street: m['street'], module: m['module'], level: m['level'],
    position: m['position'], isOccupied: m['isOccupied'] ?? false,
    currentLotId: m['currentLotId'],
  );
}

// ─── LOT ───────────────────────────────────────────────────────────────────

class Lot {
  final String id;
  final String clientId;
  final String productId;
  String productName;
  String productSku;
  int receivedQuantity;
  int currentQuantity;
  final DateTime receivedAt;
  String invoiceNumber;
  String addressId;
  String addressCode;
  String barcode;
  bool isActive;
  List<LotMovement> movements;

  Lot({
    required this.id,
    required this.clientId,
    required this.productId,
    required this.productName,
    required this.productSku,
    required this.receivedQuantity,
    required this.currentQuantity,
    required this.receivedAt,
    required this.invoiceNumber,
    required this.addressId,
    required this.addressCode,
    required this.barcode,
    this.isActive = true,
    List<LotMovement>? movements,
  }) : movements = movements ?? [];

  bool get hasStock => currentQuantity > 0;

  Map<String, dynamic> toMap() => {
    'id': id, 'clientId': clientId, 'productId': productId,
    'productName': productName, 'productSku': productSku,
    'receivedQuantity': receivedQuantity, 'currentQuantity': currentQuantity,
    'receivedAt': receivedAt.toIso8601String(), 'invoiceNumber': invoiceNumber,
    'addressId': addressId, 'addressCode': addressCode, 'barcode': barcode,
    'isActive': isActive,
    'movements': movements.map((m) => m.toMap()).toList(),
  };

  factory Lot.fromMap(Map<String, dynamic> m) => Lot(
    id: m['id'], clientId: m['clientId'], productId: m['productId'],
    productName: m['productName'], productSku: m['productSku'],
    receivedQuantity: m['receivedQuantity'], currentQuantity: m['currentQuantity'],
    receivedAt: _parseDate(m['receivedAt']),
    invoiceNumber: m['invoiceNumber'], addressId: m['addressId'],
    addressCode: m['addressCode'], barcode: m['barcode'],
    isActive: m['isActive'] ?? true,
    movements: (m['movements'] as List? ?? [])
        .map((e) => LotMovement.fromMap(e)).toList(),
  );
}

class LotMovement {
  final String type; // 'entrada' | 'saida'
  final int quantity;
  final DateTime date;
  final String reference; // order id or receiving id
  final String description;

  LotMovement({
    required this.type,
    required this.quantity,
    required this.date,
    required this.reference,
    required this.description,
  });

  Map<String, dynamic> toMap() => {
    'type': type, 'quantity': quantity, 'date': date.toIso8601String(),
    'reference': reference, 'description': description,
  };

  factory LotMovement.fromMap(Map<String, dynamic> m) => LotMovement(
    type: m['type'], quantity: m['quantity'],
    date: _parseDate(m['date']),
    reference: m['reference'], description: m['description'],
  );
}

// ─── ORDER EVENT (histórico rastreável) ────────────────────────────────────

class OrderEvent {
  final String id;
  final DateTime date;
  final String userId;
  final String userName;
  final String action;       // 'criado', 'separacao_iniciada', 'separacao_concluida', 'faturado', 'enviado', 'finalizado'
  final String description;

  OrderEvent({
    required this.id,
    required this.date,
    required this.userId,
    required this.userName,
    required this.action,
    required this.description,
  });

  Map<String, dynamic> toMap() => {
    'id': id, 'date': date.toIso8601String(),
    'userId': userId, 'userName': userName,
    'action': action, 'description': description,
  };

  factory OrderEvent.fromMap(Map<String, dynamic> m) => OrderEvent(
    id: m['id'], date: _parseDate(m['date']),
    userId: m['userId'], userName: m['userName'],
    action: m['action'], description: m['description'],
  );
}

// ─── ORDER ─────────────────────────────────────────────────────────────────

class Order {
  final String id;
  final String clientId;
  String clientName;
  String invoiceNumber;
  String accessKey; // Chave de acesso NF-e (44 dígitos)
  final DateTime createdAt;
  final String createdByUserId;
  final String createdByUserName;
  DateTime? updatedAt;
  OrderStatus status;
  OrderSize size;
  double orderValue;
  List<OrderItem> items;
  List<SeparationTask> separationTasks;
  List<OrderEvent> events;
  String? notes;
  bool isBilled;

  Order({
    required this.id,
    required this.clientId,
    required this.clientName,
    required this.invoiceNumber,
    this.accessKey = '',
    required this.createdAt,
    this.createdByUserId = '',
    this.createdByUserName = '',
    this.updatedAt,
    this.status = OrderStatus.recebido,
    this.size = OrderSize.pequeno,
    this.orderValue = 0,
    List<OrderItem>? items,
    List<SeparationTask>? separationTasks,
    List<OrderEvent>? events,
    this.notes,
    this.isBilled = false,
  }) : items = items ?? [],
       separationTasks = separationTasks ?? [],
       events = events ?? [];

  Map<String, dynamic> toMap() => {
    'id': id, 'clientId': clientId, 'clientName': clientName,
    'invoiceNumber': invoiceNumber, 'accessKey': accessKey,
    'createdAt': createdAt.toIso8601String(),
    'createdByUserId': createdByUserId, 'createdByUserName': createdByUserName,
    'updatedAt': updatedAt?.toIso8601String(), 'status': status.index,
    'size': size.index, 'orderValue': orderValue, 'notes': notes,
    'isBilled': isBilled,
    'items': items.map((i) => i.toMap()).toList(),
    'separationTasks': separationTasks.map((t) => t.toMap()).toList(),
    'events': events.map((e) => e.toMap()).toList(),
  };

  factory Order.fromMap(Map<String, dynamic> m) => Order(
    id: m['id'], clientId: m['clientId'], clientName: m['clientName'],
    invoiceNumber: m['invoiceNumber'],
    accessKey: m['accessKey'] ?? '',
    createdAt: _parseDate(m['createdAt']),
    createdByUserId: m['createdByUserId'] ?? '',
    createdByUserName: m['createdByUserName'] ?? '',
    updatedAt: m['updatedAt'] != null ? _parseDate(m['updatedAt']) : null,
    status: OrderStatus.values[m['status'] ?? 0],
    size: OrderSize.values[m['size'] ?? 0],
    orderValue: (m['orderValue'] ?? 0).toDouble(),
    notes: m['notes'],
    isBilled: m['isBilled'] ?? false,
    items: (m['items'] as List? ?? []).map((i) => OrderItem.fromMap(i)).toList(),
    separationTasks: (m['separationTasks'] as List? ?? [])
        .map((t) => SeparationTask.fromMap(t)).toList(),
    events: (m['events'] as List? ?? []).map((e) => OrderEvent.fromMap(e)).toList(),
  );
}

class OrderItem {
  final String productId;
  String productName;
  String sku;
  int quantity;
  int separatedQuantity;
  OrderSize itemSize;

  OrderItem({
    required this.productId,
    required this.productName,
    required this.sku,
    required this.quantity,
    this.separatedQuantity = 0,
    this.itemSize = OrderSize.pequeno,
  });

  bool get isFullySeparated => separatedQuantity >= quantity;

  Map<String, dynamic> toMap() => {
    'productId': productId, 'productName': productName, 'sku': sku,
    'quantity': quantity, 'separatedQuantity': separatedQuantity,
    'itemSize': itemSize.index,
  };

  factory OrderItem.fromMap(Map<String, dynamic> m) => OrderItem(
    productId: m['productId'], productName: m['productName'], sku: m['sku'],
    quantity: m['quantity'], separatedQuantity: m['separatedQuantity'] ?? 0,
    itemSize: OrderSize.values[m['itemSize'] ?? 0],
  );
}

class SeparationTask {
  final String lotId;
  String lotBarcode;
  String addressCode;
  String addressId;
  String productName;
  String productSku;
  int quantity;
  bool isCompleted;
  bool addressScanned;
  bool lotScanned;

  SeparationTask({
    required this.lotId,
    required this.lotBarcode,
    required this.addressCode,
    required this.addressId,
    required this.productName,
    required this.productSku,
    required this.quantity,
    this.isCompleted = false,
    this.addressScanned = false,
    this.lotScanned = false,
  });

  Map<String, dynamic> toMap() => {
    'lotId': lotId, 'lotBarcode': lotBarcode, 'addressCode': addressCode,
    'addressId': addressId, 'productName': productName, 'productSku': productSku,
    'quantity': quantity, 'isCompleted': isCompleted,
    'addressScanned': addressScanned, 'lotScanned': lotScanned,
  };

  factory SeparationTask.fromMap(Map<String, dynamic> m) => SeparationTask(
    lotId: m['lotId'], lotBarcode: m['lotBarcode'], addressCode: m['addressCode'],
    addressId: m['addressId'], productName: m['productName'], productSku: m['productSku'],
    quantity: m['quantity'], isCompleted: m['isCompleted'] ?? false,
    addressScanned: m['addressScanned'] ?? false, lotScanned: m['lotScanned'] ?? false,
  );
}

// ─── RECEIVING RECORD ──────────────────────────────────────────────────────

class ReceivingRecord {
  final String id;
  final String clientId;
  String clientName;
  String invoiceNumber;
  final DateTime receivedAt;
  List<ReceivingItem> items;
  String operatorName;
  bool isCompleted;

  ReceivingRecord({
    required this.id,
    required this.clientId,
    required this.clientName,
    required this.invoiceNumber,
    required this.receivedAt,
    List<ReceivingItem>? items,
    required this.operatorName,
    this.isCompleted = false,
  }) : items = items ?? [];

  Map<String, dynamic> toMap() => {
    'id': id, 'clientId': clientId, 'clientName': clientName,
    'invoiceNumber': invoiceNumber, 'receivedAt': receivedAt.toIso8601String(),
    'operatorName': operatorName, 'isCompleted': isCompleted,
    'items': items.map((i) => i.toMap()).toList(),
  };

  factory ReceivingRecord.fromMap(Map<String, dynamic> m) => ReceivingRecord(
    id: m['id'], clientId: m['clientId'], clientName: m['clientName'],
    invoiceNumber: m['invoiceNumber'],
    receivedAt: _parseDate(m['receivedAt']),
    operatorName: m['operatorName'], isCompleted: m['isCompleted'] ?? false,
    items: (m['items'] as List? ?? []).map((i) => ReceivingItem.fromMap(i)).toList(),
  );
}

class ReceivingItem {
  String productId;
  String productName;
  String sku;
  int quantity;
  String lotId;
  String addressId;
  String addressCode;

  ReceivingItem({
    required this.productId,
    required this.productName,
    required this.sku,
    required this.quantity,
    this.lotId = '',
    this.addressId = '',
    this.addressCode = '',
  });

  Map<String, dynamic> toMap() => {
    'productId': productId, 'productName': productName, 'sku': sku,
    'quantity': quantity, 'lotId': lotId, 'addressId': addressId,
    'addressCode': addressCode,
  };

  factory ReceivingItem.fromMap(Map<String, dynamic> m) => ReceivingItem(
    productId: m['productId'], productName: m['productName'], sku: m['sku'],
    quantity: m['quantity'], lotId: m['lotId'] ?? '',
    addressId: m['addressId'] ?? '', addressCode: m['addressCode'] ?? '',
  );
}

// ─── BILLING ───────────────────────────────────────────────────────────────

class MonthlyBilling {
  final String id;
  final String clientId;
  String clientName;
  final int year;
  final int month;
  int smallOrders;
  int mediumOrders;
  int largeOrders;
  int envelopeOrders;
  double calculatedValue;
  double minimumMonthly;
  double finalValue;
  bool isPaid;
  DateTime? paidAt;

  MonthlyBilling({
    required this.id,
    required this.clientId,
    required this.clientName,
    required this.year,
    required this.month,
    this.smallOrders = 0,
    this.mediumOrders = 0,
    this.largeOrders = 0,
    this.envelopeOrders = 0,
    this.calculatedValue = 0,
    required this.minimumMonthly,
    this.finalValue = 0,
    this.isPaid = false,
    this.paidAt,
  });

  int get totalOrders => smallOrders + mediumOrders + largeOrders + envelopeOrders;
  String get monthLabel {
    const months = ['Jan','Fev','Mar','Abr','Mai','Jun','Jul','Ago','Set','Out','Nov','Dez'];
    return '${months[month - 1]}/$year';
  }

  Map<String, dynamic> toMap() => {
    'id': id, 'clientId': clientId, 'clientName': clientName,
    'year': year, 'month': month, 'smallOrders': smallOrders,
    'mediumOrders': mediumOrders, 'largeOrders': largeOrders,
    'envelopeOrders': envelopeOrders,
    'calculatedValue': calculatedValue, 'minimumMonthly': minimumMonthly,
    'finalValue': finalValue, 'isPaid': isPaid,
    'paidAt': paidAt?.toIso8601String(),
  };

  factory MonthlyBilling.fromMap(Map<String, dynamic> m) => MonthlyBilling(
    id: m['id'], clientId: m['clientId'], clientName: m['clientName'],
    year: m['year'], month: m['month'],
    smallOrders: m['smallOrders'] ?? 0, mediumOrders: m['mediumOrders'] ?? 0,
    largeOrders: m['largeOrders'] ?? 0,
    envelopeOrders: m['envelopeOrders'] ?? 0,
    calculatedValue: (m['calculatedValue'] ?? 0).toDouble(),
    minimumMonthly: (m['minimumMonthly'] ?? 0).toDouble(),
    finalValue: (m['finalValue'] ?? 0).toDouble(),
    isPaid: m['isPaid'] ?? false,
    paidAt: m['paidAt'] != null ? _parseDate(m['paidAt']) : null,
  );
}

// ─── APP NOTIFICATION ──────────────────────────────────────────────────────

class AppNotification {
  final String id;
  final String targetUserId;   // ID do usuário que deve receber a notificação
  final NotificationType type;
  final String title;
  final String body;
  final String? referenceId;   // orderId ou lotId relacionado
  bool isRead;
  final DateTime createdAt;

  AppNotification({
    required this.id,
    required this.targetUserId,
    required this.type,
    required this.title,
    required this.body,
    this.referenceId,
    this.isRead = false,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id, 'targetUserId': targetUserId, 'type': type.index,
    'title': title, 'body': body, 'referenceId': referenceId,
    'isRead': isRead, 'createdAt': createdAt.toIso8601String(),
  };

  factory AppNotification.fromMap(Map<String, dynamic> m) => AppNotification(
    id: m['id'], targetUserId: m['targetUserId'],
    type: NotificationType.values[m['type'] ?? 0],
    title: m['title'], body: m['body'],
    referenceId: m['referenceId'],
    isRead: m['isRead'] ?? false,
    createdAt: _parseDate(m['createdAt']),
  );
}

// ─── USER STATS (produtividade por funcionário) ────────────────────────────

class UserStats {
  final String userId;
  final String userName;
  final UserRole role;
  int ordersCreated;     // pedidos criados (clientes)
  int receivingsCount;   // recebimentos realizados
  int separationsCount;  // separações concluídas
  int shippedCount;      // pedidos marcados como enviados
  int finalizedCount;    // pedidos finalizados

  UserStats({
    required this.userId,
    required this.userName,
    required this.role,
    this.ordersCreated = 0,
    this.receivingsCount = 0,
    this.separationsCount = 0,
    this.shippedCount = 0,
    this.finalizedCount = 0,
  });

  int get totalActions => ordersCreated + receivingsCount + separationsCount + shippedCount + finalizedCount;
}

// ─── GLOBAL EVENT (evento com contexto de pedido) ─────────────────────────

class GlobalEvent {
  final OrderEvent event;
  final String orderId;
  final String invoiceNumber;
  final String clientName;
  final String clientId;

  GlobalEvent({
    required this.event,
    required this.orderId,
    required this.invoiceNumber,
    required this.clientName,
    required this.clientId,
  });
}

// ─── NF-e XML PARSE RESULT ────────────────────────────────────────────────────

class NfeItem {
  final String cProd;   // Código do produto na NF-e
  final String cEAN;    // EAN/GTIN (vazio se "SEM GTIN")
  final String xProd;   // Descrição do produto
  final int quantity;

  const NfeItem({
    required this.cProd,
    required this.cEAN,
    required this.xProd,
    required this.quantity,
  });
}

class NfeParseResult {
  final String invoiceNumber;
  final String accessKey;   // Chave de acesso 44 dígitos (chNFe)
  final String clientCnpj;
  final String clientName;
  final List<NfeItem> items;
  final String rawXml;
  final String? error;

  const NfeParseResult({
    required this.invoiceNumber,
    this.accessKey = '',
    required this.clientCnpj,
    required this.clientName,
    required this.items,
    required this.rawXml,
    this.error,
  });

  bool get hasError => error != null;
}

// ─── STORAGE STATS ────────────────────────────────────────────────────────

class StorageStats {
  final int activeOrders;
  final int archivedOrders;
  final int activeLots;
  final int totalMovements;
  final int totalNotifications;
  final int totalReceivings;
  final int ordersToArchive;
  final int archivesToDelete;
  final int oldMovementsToCompact;
  final int oldNotificationsToDelete;
  final int orphanLotsToClean;
  final int estimatedStorageBytes;
  final DateTime? lastCleanupAt;

  const StorageStats({
    required this.activeOrders,
    required this.archivedOrders,
    required this.activeLots,
    required this.totalMovements,
    required this.totalNotifications,
    required this.totalReceivings,
    required this.ordersToArchive,
    required this.archivesToDelete,
    required this.oldMovementsToCompact,
    required this.oldNotificationsToDelete,
    required this.orphanLotsToClean,
    required this.estimatedStorageBytes,
    this.lastCleanupAt,
  });

  int get totalItemsToClean =>
      ordersToArchive + archivesToDelete + oldMovementsToCompact +
      oldNotificationsToDelete + orphanLotsToClean;

  String get estimatedStorageFormatted {
    if (estimatedStorageBytes < 1024) return '$estimatedStorageBytes B';
    if (estimatedStorageBytes < 1024 * 1024) {
      return '${(estimatedStorageBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(estimatedStorageBytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }
}

// ─── CLEANUP REPORT ──────────────────────────────────────────────────────

class CleanupReport {
  final int archivedOrders;
  final int deletedArchives;
  final int compactedMovements;
  final int deletedNotifications;
  final int cleanedOrphanLots;
  final int trimmedEvents;
  final DateTime executedAt;
  final bool isDryRun;

  const CleanupReport({
    required this.archivedOrders,
    required this.deletedArchives,
    required this.compactedMovements,
    required this.deletedNotifications,
    required this.cleanedOrphanLots,
    required this.trimmedEvents,
    required this.executedAt,
    required this.isDryRun,
  });

  int get totalActions =>
      archivedOrders + deletedArchives + compactedMovements +
      deletedNotifications + cleanedOrphanLots + trimmedEvents;

  bool get hasChanges => totalActions > 0;
}

// ─── PACKAGE TYPE (tipo de embalagem editável) ────────────────────────────

class PackageType {
  String id;
  String name;          // "Caixa Pequena", "Envelope", etc.
  String description;
  double maxWeightKg;   // peso máximo suportado
  double maxLengthCm;
  double maxWidthCm;
  double maxHeightCm;
  bool isActive;
  final DateTime createdAt;

  PackageType({
    required this.id,
    required this.name,
    this.description = '',
    required this.maxWeightKg,
    this.maxLengthCm = 0,
    this.maxWidthCm = 0,
    this.maxHeightCm = 0,
    this.isActive = true,
    required this.createdAt,
  });

  double get maxVolumeCm3 => maxLengthCm * maxWidthCm * maxHeightCm;

  Map<String, dynamic> toMap() => {
    'id': id, 'name': name, 'description': description,
    'maxWeightKg': maxWeightKg, 'maxLengthCm': maxLengthCm,
    'maxWidthCm': maxWidthCm, 'maxHeightCm': maxHeightCm,
    'isActive': isActive, 'createdAt': createdAt.toIso8601String(),
  };

  factory PackageType.fromMap(Map<String, dynamic> m) => PackageType(
    id: m['id'], name: m['name'],
    description: m['description'] ?? '',
    maxWeightKg: (m['maxWeightKg'] ?? 1).toDouble(),
    maxLengthCm: (m['maxLengthCm'] ?? 0).toDouble(),
    maxWidthCm: (m['maxWidthCm'] ?? 0).toDouble(),
    maxHeightCm: (m['maxHeightCm'] ?? 0).toDouble(),
    isActive: m['isActive'] ?? true,
    createdAt: _parseDate(m['createdAt']),
  );
}

// ─── SUPPORT TICKET ──────────────────────────────────────────────────────

enum TicketStatus { open, inProgress, pendingClient, resolved, closed }
enum TicketPriority { low, normal, high, urgent }
enum TicketCategory { 
  general, shipping, billing, stock, damage, return_product, 
  technical, complaint, other
}

extension TicketStatusExt on TicketStatus {
  String get label {
    switch (this) {
      case TicketStatus.open: return 'Aberto';
      case TicketStatus.inProgress: return 'Em Atendimento';
      case TicketStatus.pendingClient: return 'Aguardando Cliente';
      case TicketStatus.resolved: return 'Resolvido';
      case TicketStatus.closed: return 'Encerrado';
    }
  }
  bool get isActive => this == TicketStatus.open || this == TicketStatus.inProgress || this == TicketStatus.pendingClient;
}

extension TicketPriorityExt on TicketPriority {
  String get label {
    switch (this) {
      case TicketPriority.low: return 'Baixa';
      case TicketPriority.normal: return 'Normal';
      case TicketPriority.high: return 'Alta';
      case TicketPriority.urgent: return 'Urgente';
    }
  }
}

extension TicketCategoryExt on TicketCategory {
  String get label {
    switch (this) {
      case TicketCategory.general: return 'Geral';
      case TicketCategory.shipping: return 'Envio/Frete';
      case TicketCategory.billing: return 'Faturamento';
      case TicketCategory.stock: return 'Estoque';
      case TicketCategory.damage: return 'Avaria';
      case TicketCategory.return_product: return 'Devolução';
      case TicketCategory.technical: return 'Técnico';
      case TicketCategory.complaint: return 'Reclamação';
      case TicketCategory.other: return 'Outro';
    }
  }
}

class TicketMessage {
  final String id;
  final String senderId;
  final String senderName;
  final UserRole senderRole;
  final String text;
  final DateTime sentAt;
  final bool isSystem;
  final String? attachmentUrl;   // base64 data-url ou URL remota
  final String? attachmentName;  // nome do arquivo
  final String? attachmentType;  // 'image' | 'file'

  TicketMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.senderRole,
    required this.text,
    required this.sentAt,
    this.isSystem = false,
    this.attachmentUrl,
    this.attachmentName,
    this.attachmentType,
  });

  Map<String, dynamic> toMap() => {
    'id': id, 'senderId': senderId, 'senderName': senderName,
    'senderRole': senderRole.index, 'text': text,
    'sentAt': sentAt.toIso8601String(), 'isSystem': isSystem,
    if (attachmentUrl != null) 'attachmentUrl': attachmentUrl,
    if (attachmentName != null) 'attachmentName': attachmentName,
    if (attachmentType != null) 'attachmentType': attachmentType,
  };

  factory TicketMessage.fromMap(Map<String, dynamic> m) => TicketMessage(
    id: m['id'], senderId: m['senderId'], senderName: m['senderName'],
    senderRole: UserRole.values[m['senderRole'] ?? 0],
    text: m['text'], sentAt: _parseDate(m['sentAt']),
    isSystem: m['isSystem'] ?? false,
    attachmentUrl: m['attachmentUrl'],
    attachmentName: m['attachmentName'],
    attachmentType: m['attachmentType'],
  );
}

class SupportTicket {
  final String id;
  final String clientId;
  final String clientName;
  final String createdByUserId;
  final String createdByUserName;
  TicketStatus status;
  TicketPriority priority;
  TicketCategory category;
  final String subject;
  String? relatedOrderId;
  String? relatedOrderInvoice;
  String? assignedToUserId;
  String? assignedToUserName;
  final List<TicketMessage> messages;
  int? rating;           // 1-5 stars after resolution
  String? ratingComment;
  final DateTime createdAt;
  DateTime? updatedAt;
  DateTime? resolvedAt;
  // Return product fields
  bool isReturnRequest;
  String? returnLotId;
  bool? returnToStock;
  bool? returnApprovedByAdmin;
  // Novos campos
  String? agentNotes;          // observações livres do funcionário
  int? returnQuantity;          // quantidade de itens na devolução
  String? returnOrderInvoice;   // NF da devolução (busca rápida)
  bool adminApproved;           // admin aprovou o chamado
  String? adminApprovalNote;    // nota do admin na aprovação
  bool adminRejected;           // admin recusou o chamado
  String? adminRejectionNote;   // motivo da recusa
  DateTime? startedAt;          // quando o atendente aceitou (para calcular tempo)
  bool createdByStaff;           // true = chamado criado por funcionário (não cliente)

  SupportTicket({
    required this.id,
    required this.clientId,
    required this.clientName,
    required this.createdByUserId,
    required this.createdByUserName,
    this.status = TicketStatus.open,
    this.priority = TicketPriority.normal,
    required this.category,
    required this.subject,
    this.relatedOrderId,
    this.relatedOrderInvoice,
    this.assignedToUserId,
    this.assignedToUserName,
    List<TicketMessage>? messages,
    this.rating,
    this.ratingComment,
    required this.createdAt,
    this.updatedAt,
    this.resolvedAt,
    this.isReturnRequest = false,
    this.returnLotId,
    this.returnToStock,
    this.returnApprovedByAdmin,
    this.agentNotes,
    this.returnQuantity,
    this.returnOrderInvoice,
    this.adminApproved = false,
    this.adminApprovalNote,
    this.adminRejected = false,
    this.adminRejectionNote,
    this.startedAt,
    this.createdByStaff = false,
  }) : messages = messages ?? [];

  Map<String, dynamic> toMap() => {
    'id': id, 'clientId': clientId, 'clientName': clientName,
    'createdByUserId': createdByUserId, 'createdByUserName': createdByUserName,
    'status': status.index, 'priority': priority.index,
    'category': category.index, 'subject': subject,
    'relatedOrderId': relatedOrderId, 'relatedOrderInvoice': relatedOrderInvoice,
    'assignedToUserId': assignedToUserId, 'assignedToUserName': assignedToUserName,
    'messages': messages.map((m) => m.toMap()).toList(),
    'rating': rating, 'ratingComment': ratingComment,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
    'resolvedAt': resolvedAt?.toIso8601String(),
    'isReturnRequest': isReturnRequest,
    'returnLotId': returnLotId,
    'returnToStock': returnToStock,
    'returnApprovedByAdmin': returnApprovedByAdmin,
    'agentNotes': agentNotes,
    'returnQuantity': returnQuantity,
    'returnOrderInvoice': returnOrderInvoice,
    'adminApproved': adminApproved,
    'adminApprovalNote': adminApprovalNote,
    'adminRejected': adminRejected,
    'adminRejectionNote': adminRejectionNote,
    'startedAt': startedAt?.toIso8601String(),
    'createdByStaff': createdByStaff,
  };

  factory SupportTicket.fromMap(Map<String, dynamic> m) => SupportTicket(
    id: m['id'], clientId: m['clientId'], clientName: m['clientName'],
    createdByUserId: m['createdByUserId'], createdByUserName: m['createdByUserName'],
    status: TicketStatus.values[m['status'] ?? 0],
    priority: TicketPriority.values[m['priority'] ?? 1],
    category: TicketCategory.values[m['category'] ?? 0],
    subject: m['subject'],
    relatedOrderId: m['relatedOrderId'],
    relatedOrderInvoice: m['relatedOrderInvoice'],
    assignedToUserId: m['assignedToUserId'],
    assignedToUserName: m['assignedToUserName'],
    messages: (m['messages'] as List? ?? []).map((x) => TicketMessage.fromMap(x)).toList(),
    rating: m['rating'],
    ratingComment: m['ratingComment'],
    createdAt: _parseDate(m['createdAt']),
    updatedAt: m['updatedAt'] != null ? _parseDate(m['updatedAt']) : null,
    resolvedAt: m['resolvedAt'] != null ? _parseDate(m['resolvedAt']) : null,
    isReturnRequest: m['isReturnRequest'] ?? false,
    returnLotId: m['returnLotId'],
    returnToStock: m['returnToStock'],
    returnApprovedByAdmin: m['returnApprovedByAdmin'],
    agentNotes: m['agentNotes'],
    returnQuantity: m['returnQuantity'],
    returnOrderInvoice: m['returnOrderInvoice'],
    createdByStaff: m['createdByStaff'] ?? false,
    adminApproved: m['adminApproved'] ?? false,
    adminApprovalNote: m['adminApprovalNote'],
    adminRejected: m['adminRejected'] ?? false,
    adminRejectionNote: m['adminRejectionNote'],
    startedAt: m['startedAt'] != null ? _parseDate(m['startedAt']) : null,
  );
}

// ─── SUPPORT SETTINGS (horário de atendimento) ────────────────────────────

class SupportSettings {
  bool isOnline;               // atendimento ativo agora
  String offlineMessage;       // mensagem fora do horário
  String waitMessage;          // mensagem de espera
  List<int> workDays;          // 1=Seg, 2=Ter, ..., 7=Dom
  int startHour;
  int startMinute;
  int endHour;
  int endMinute;

  SupportSettings({
    this.isOnline = true,
    this.offlineMessage = 'No momento não estamos disponíveis. Seu chamado será respondido no próximo horário de atendimento.',
    this.waitMessage = 'Olá! Recebemos seu chamado e em breve um atendente irá responder.',
    this.workDays = const [1, 2, 3, 4, 5],
    this.startHour = 8,
    this.startMinute = 0,
    this.endHour = 18,
    this.endMinute = 0,
  });

  bool get isWithinWorkHours {
    final now = DateTime.now();
    final weekday = now.weekday; // 1=Seg, 7=Dom
    if (!workDays.contains(weekday)) return false;
    final currentMinutes = now.hour * 60 + now.minute;
    final startMinutes = startHour * 60 + startMinute;
    final endMinutes = endHour * 60 + endMinute;
    return currentMinutes >= startMinutes && currentMinutes <= endMinutes;
  }

  Map<String, dynamic> toMap() => {
    'isOnline': isOnline, 'offlineMessage': offlineMessage,
    'waitMessage': waitMessage, 'workDays': workDays,
    'startHour': startHour, 'startMinute': startMinute,
    'endHour': endHour, 'endMinute': endMinute,
  };

  factory SupportSettings.fromMap(Map<String, dynamic> m) => SupportSettings(
    isOnline: m['isOnline'] ?? true,
    offlineMessage: m['offlineMessage'] ?? 'No momento não estamos disponíveis.',
    waitMessage: m['waitMessage'] ?? 'Olá! Recebemos seu chamado.',
    workDays: (m['workDays'] as List? ?? [1,2,3,4,5]).cast<int>(),
    startHour: m['startHour'] ?? 8,
    startMinute: m['startMinute'] ?? 0,
    endHour: m['endHour'] ?? 18,
    endMinute: m['endMinute'] ?? 0,
  );
}

// ─── BILLING EXTRA (valores adicionais e descontos) ──────────────────────

class BillingExtra {
  final String id;
  final String clientId;
  final int year;
  final int month;
  final String description;
  final double value;  // positivo = adicionar, negativo = desconto
  final String createdByUserId;
  final DateTime createdAt;

  BillingExtra({
    required this.id,
    required this.clientId,
    required this.year,
    required this.month,
    required this.description,
    required this.value,
    required this.createdByUserId,
    required this.createdAt,
  });

  bool get isDiscount => value < 0;
  bool get isExtra => value > 0;

  Map<String, dynamic> toMap() => {
    'id': id, 'clientId': clientId, 'year': year, 'month': month,
    'description': description, 'value': value,
    'createdByUserId': createdByUserId,
    'createdAt': createdAt.toIso8601String(),
  };

  factory BillingExtra.fromMap(Map<String, dynamic> m) => BillingExtra(
    id: m['id'], clientId: m['clientId'],
    year: m['year'], month: m['month'],
    description: m['description'],
    value: (m['value'] ?? 0).toDouble(),
    createdByUserId: m['createdByUserId'],
    createdAt: _parseDate(m['createdAt']),
  );
}
