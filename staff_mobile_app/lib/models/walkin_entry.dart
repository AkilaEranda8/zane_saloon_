class WalkInEntry {
  WalkInEntry({
    required this.id,
    required this.token,
    required this.customerName,
    required this.phone,
    required this.status,
    required this.branchId,
    required this.serviceId,
    required this.serviceName,
    required this.staffId,
    required this.staffName,
    required this.estimatedWait,
    required this.note,
    this.totalAmount = 0,
    this.walkInServicesPayload,
  });

  final String id;
  final String token;
  final String customerName;
  final String phone;
  final String status;
  final String branchId;
  final String serviceId;
  final String serviceName;
  final String staffId;
  final String staffName;
  final int estimatedWait;
  final String note;
  /// Sum of selected services (from API `total_amount`).
  final double totalAmount;

  /// Raw `walkInServices` rows from API (for cache). Optional.
  final List<Map<String, dynamic>>? walkInServicesPayload;

  factory WalkInEntry.fromJson(Map<String, dynamic> json) {
    final service = json['service'] is Map ? Map<String, dynamic>.from(json['service']) : const <String, dynamic>{};
    final staff = json['staff'] is Map ? Map<String, dynamic>.from(json['staff']) : const <String, dynamic>{};
    final rawTotal = json['total_amount'];
    final total = rawTotal is num
        ? rawTotal.toDouble()
        : double.tryParse('$rawTotal') ?? 0.0;

    List<Map<String, dynamic>>? linesPayload;
    var displayName = '${service['name'] ?? ''}';
    final wiq = json['walkInServices'];
    if (wiq is List && wiq.isNotEmpty) {
      linesPayload = wiq
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
      final names = <String>[];
      for (final m in linesPayload) {
        final nested = m['service'];
        if (nested is Map) {
          final n = '${Map<String, dynamic>.from(nested)['name'] ?? ''}'.trim();
          if (n.isNotEmpty) names.add(n);
        }
      }
      if (names.isNotEmpty) displayName = names.join(', ');
    }

    return WalkInEntry(
      id: '${json['id'] ?? ''}',
      token: '${json['token'] ?? ''}',
      customerName: '${json['customer_name'] ?? ''}',
      phone: '${json['phone'] ?? ''}',
      status: '${json['status'] ?? 'waiting'}',
      branchId: '${json['branch_id'] ?? ''}',
      serviceId: '${json['service_id'] ?? service['id'] ?? ''}',
      serviceName: displayName,
      staffId: '${json['staff_id'] ?? staff['id'] ?? ''}',
      staffName: '${staff['name'] ?? ''}',
      estimatedWait: int.tryParse('${json['estimated_wait'] ?? 0}') ?? 0,
      note: '${json['note'] ?? ''}',
      totalAmount: total,
      walkInServicesPayload: linesPayload,
    );
  }

  Map<String, dynamic> toJson() {
    final sid = int.tryParse(staffId);
    final map = <String, dynamic>{
      'id': int.tryParse(id) ?? id,
      'token': token,
      'customer_name': customerName,
      'phone': phone,
      'status': status,
      'branch_id': int.tryParse(branchId) ?? branchId,
      'service_id': int.tryParse(serviceId) ?? serviceId,
      'staff_id': staffId.isEmpty ? null : (sid ?? staffId),
      'estimated_wait': estimatedWait,
      'note': note,
      'total_amount': totalAmount,
      'service': {
        'id': int.tryParse(serviceId) ?? serviceId,
        'name': serviceName,
      },
    };
    if (staffId.isNotEmpty) {
      map['staff'] = {'id': sid ?? staffId, 'name': staffName};
    }
    final wiq = walkInServicesPayload;
    if (wiq != null && wiq.isNotEmpty) {
      map['walkInServices'] = wiq;
    }
    return map;
  }
}
