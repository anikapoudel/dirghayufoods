class OrderLineItem {
  final String title;
  final String weight;
  final int quantity;
  final double unitPrice;

  const OrderLineItem({
    required this.title,
    this.weight = '',
    required this.quantity,
    required this.unitPrice,
  });

  double get lineTotal => unitPrice * quantity;
}

class DeliveryAddress {
  final String receiverName;
  final String phoneNumber;
  final String province;
  final String district;
  final String municipality;
  final String wardNumber;
  final String streetName;
  final String landmark;
  final String notes;

  const DeliveryAddress({
    required this.receiverName,
    required this.phoneNumber,
    required this.province,
    required this.district,
    required this.municipality,
    required this.wardNumber,
    required this.streetName,
    this.landmark = '',
    this.notes = '',
  });

  String get stateValue => province.replaceAll(' Province', '').trim();

  String get cityValue => municipality;

  String get streetAddressValue {
    final parts = <String>[streetName, 'Ward $wardNumber'];
    if (landmark.trim().isNotEmpty) parts.add('Near $landmark');
    return parts.join(', ');
  }

  String get shortLine => '$streetName, Ward $wardNumber';

  String get cityLine => '$municipality, $district';
}

enum PaymentMethod { cashOnDelivery }

extension PaymentMethodLabel on PaymentMethod {
  String get label {
    switch (this) {
      case PaymentMethod.cashOnDelivery:
        return 'Cash on Delivery (COD)';
    }
  }

  String get apiValue {
    switch (this) {
      case PaymentMethod.cashOnDelivery:
        return 'cash_on_delivery';
    }
  }
}

class CreateOrderRequest {
  final String fullName;
  final String email;
  final String phone;
  final String state;
  final String district;
  final String city;
  final String streetAddress;
  final PaymentMethod paymentMethod;
  final String notes;

  const CreateOrderRequest({
    required this.fullName,
    required this.email,
    required this.phone,
    required this.state,
    required this.district,
    required this.city,
    required this.streetAddress,
    required this.paymentMethod,
    this.notes = '',
  });

  Map<String, dynamic> toJson() => {
    'full_name': fullName,
    'email': email,
    'phone': phone,
    'state': state,
    'district': district,
    'city': city,
    'street_address': streetAddress,
    'payment_method': paymentMethod.apiValue,
    'notes': notes,
  };
}

class CreateOrderResult {
  final String orderId;
  final String orderReference;

  const CreateOrderResult({
    required this.orderId,
    required this.orderReference,
  });

  factory CreateOrderResult.fromJson(Map<String, dynamic> json) {
    return CreateOrderResult(
      orderId: json['order_id']?.toString() ?? '',
      orderReference: json['order_reference']?.toString() ?? '',
    );
  }
}

class PlacedOrderSummary {
  final String orderId;
  final String orderReference;
  final List<OrderLineItem> items;
  final DeliveryAddress address;
  final PaymentMethod paymentMethod;
  final double subtotal;
  final double discount;
  final double deliveryCharge;
  final double total;

  const PlacedOrderSummary({
    required this.orderId,
    required this.orderReference,
    required this.items,
    required this.address,
    required this.paymentMethod,
    required this.subtotal,
    required this.discount,
    required this.deliveryCharge,
    required this.total,
  });

  bool get isDeliveryFree => deliveryCharge <= 0;
}

class OrderProduct {
  final String id;
  final String name;
  final String imageUrl;
  final double? price;

  const OrderProduct({
    required this.id,
    required this.name,
    required this.imageUrl,
    this.price,
  });

  factory OrderProduct.fromJson(Map<String, dynamic> json) {
    return OrderProduct(
      id: json['id']?.toString() ?? '',

      name: json['title']?.toString() ?? json['name']?.toString() ?? '',
      imageUrl: json['image_url']?.toString() ?? '',
      price: json['price'] != null
          ? double.tryParse(json['price'].toString())
          : null,
    );
  }
}

class OrderItemEntry {
  final String id;
  final int quantity;
  final double unitPrice;
  final String status;
  final OrderProduct product;

  const OrderItemEntry({
    required this.id,
    required this.quantity,
    required this.unitPrice,
    required this.status,
    required this.product,
  });

  double get lineTotal => unitPrice * quantity;

  factory OrderItemEntry.fromJson(Map<String, dynamic> json) {
    return OrderItemEntry(
      id: json['id']?.toString() ?? '',
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      unitPrice: double.tryParse(json['unit_price']?.toString() ?? '0') ?? 0,
      status: json['status']?.toString() ?? 'pending',
      product: OrderProduct.fromJson(json['product'] ?? const {}),
    );
  }
}

class OrderCustomer {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String? location;

  const OrderCustomer({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    this.location,
  });

  factory OrderCustomer.fromJson(Map<String, dynamic> json) {
    return OrderCustomer(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      location: json['location']?.toString(),
    );
  }
}

class RemoteDeliveryAddress {
  final String fullName;
  final String phone;
  final String state;
  final String district;
  final String city;
  final String streetAddress;

  const RemoteDeliveryAddress({
    required this.fullName,
    required this.phone,
    required this.state,
    required this.district,
    required this.city,
    required this.streetAddress,
  });

  factory RemoteDeliveryAddress.fromJson(Map<String, dynamic> json) {
    return RemoteDeliveryAddress(
      fullName: json['full_name']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      state: json['state']?.toString() ?? '',
      district: json['district']?.toString() ?? '',
      city: json['city']?.toString() ?? '',
      streetAddress: json['street_address']?.toString() ?? '',
    );
  }

  bool get isEmpty =>
      fullName.isEmpty &&
      phone.isEmpty &&
      state.isEmpty &&
      district.isEmpty &&
      city.isEmpty &&
      streetAddress.isEmpty;

  String get line1 => streetAddress;

  String get line2 => [city, district].where((s) => s.isNotEmpty).join(', ');

  String get line3 => state;
}

class OrderPayment {
  final String? id;
  final String method;
  final String status;
  final double amount;
  final String? transactionId;
  final DateTime? paymentDate;

  const OrderPayment({
    this.id,
    required this.method,
    required this.status,
    required this.amount,
    this.transactionId,
    this.paymentDate,
  });

  factory OrderPayment.fromJson(Map<String, dynamic> json) {
    return OrderPayment(
      id: json['id']?.toString(),
      method: json['method']?.toString() ?? 'cash_on_delivery',
      status: json['status']?.toString() ?? 'pending',
      amount: double.tryParse(json['amount']?.toString() ?? '0') ?? 0,
      transactionId: json['transaction_id']?.toString(),
      paymentDate: json['payment_date'] != null
          ? DateTime.tryParse(json['payment_date'].toString())
          : null,
    );
  }
}

class RemoteOrder {
  final String id;
  final String orderReference;
  final DateTime orderDate;
  final double totalPrice;
  final String status;
  final DateTime createdAt;
  final OrderCustomer? customer;
  final RemoteDeliveryAddress? deliveryAddress;
  final List<OrderItemEntry> items;
  final OrderPayment payment;
  final String? notes;

  const RemoteOrder({
    required this.id,
    required this.orderReference,
    required this.orderDate,
    required this.totalPrice,
    required this.status,
    required this.createdAt,
    this.customer,
    this.deliveryAddress,
    required this.items,
    required this.payment,
    this.notes,
  });

  double get itemsSubtotal =>
      items.fold(0.0, (sum, item) => sum + item.lineTotal);

  double get deliveryCharge => totalPrice - itemsSubtotal;

  factory RemoteOrder.fromJson(Map<String, dynamic> json) {
    final deliveryAddress = RemoteDeliveryAddress.fromJson(json);
    return RemoteOrder(
      id: json['id']?.toString() ?? '',
      orderReference: json['order_reference']?.toString() ?? '',
      orderDate:
          DateTime.tryParse(json['order_date']?.toString() ?? '') ??
          DateTime.now(),
      totalPrice: double.tryParse(json['total_price']?.toString() ?? '0') ?? 0,
      status: json['status']?.toString() ?? 'pending',
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
      customer: json['customer'] != null
          ? OrderCustomer.fromJson(json['customer'] as Map<String, dynamic>)
          : null,
      deliveryAddress: deliveryAddress.isEmpty ? null : deliveryAddress,
      items: (json['items'] as List<dynamic>? ?? [])
          .map((e) => OrderItemEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
      payment: OrderPayment.fromJson(json['payment'] ?? const {}),
      notes: json['notes']?.toString(),
    );
  }
}

class OrderPagination {
  final int total;
  final int page;
  final int limit;
  final int totalPages;
  final bool hasNextPage;
  final bool hasPrevPage;

  const OrderPagination({
    required this.total,
    required this.page,
    required this.limit,
    required this.totalPages,
    required this.hasNextPage,
    required this.hasPrevPage,
  });

  factory OrderPagination.fromJson(Map<String, dynamic> json) {
    return OrderPagination(
      total: (json['total'] as num?)?.toInt() ?? 0,
      page: (json['page'] as num?)?.toInt() ?? 1,
      limit: (json['limit'] as num?)?.toInt() ?? 10,
      totalPages: (json['totalPages'] as num?)?.toInt() ?? 1,
      hasNextPage: json['hasNextPage'] as bool? ?? false,
      hasPrevPage: json['hasPrevPage'] as bool? ?? false,
    );
  }
}

class OrderListResult {
  final List<RemoteOrder> orders;
  final OrderPagination pagination;

  const OrderListResult({required this.orders, required this.pagination});
}
