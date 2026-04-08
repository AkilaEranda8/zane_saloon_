import 'dart:convert';

import '../utils/appointment_notes.dart';
import 'salon_service.dart';

class Appointment {
  Appointment({
    required this.id,
    required this.customerName,
    required this.serviceName,
    required this.date,
    required this.time,
    required this.status,
    required this.createdBy,
    this.serviceId = '',
    this.serviceIds = const [],
    this.branchId = '',
    this.phone = '',
    this.notes = '',
    this.amount = 0,
    this.staffId = '',
    this.customerId = '',
    this.branchName = '',
  });

  final String id;
  final String customerName;
  final String serviceName;
  final String date;
  final String time;
  final String status;
  final String createdBy;
  final String serviceId;
  /// Ordered IDs from API (`appointment_services` / `service_ids`); preferred over notes for display.
  final List<String> serviceIds;
  final String branchId;
  final String phone;
  final String notes;
  final double amount;
  final String staffId;
  final String customerId;
  final String branchName;

  /// Primary + additional service names (from notes), de-duplicated, order preserved.
  String get servicesDisplay {
    final out = <String>[];
    if (serviceName.isNotEmpty) out.add(serviceName);
    for (final n in AppointmentNotes.parseAdditionalServiceNames(notes)) {
      if (!out.contains(n)) out.add(n);
    }
    return out.join(', ');
  }

  /// Uses [serviceIds] + catalog when present (matches DB); otherwise [servicesDisplay] / primary name.
  String resolveServicesDisplay(Iterable<SalonService> catalog) {
    if (serviceIds.isNotEmpty) {
      final byId = <String, String>{};
      for (final s in catalog) {
        byId[s.id] = s.name;
      }
      final names = <String>[];
      for (final id in serviceIds) {
        final n = byId[id];
        if (n != null && n.isNotEmpty) names.add(n);
      }
      if (names.isNotEmpty) return names.join(', ');
    }
    final legacy = servicesDisplay;
    if (legacy.isNotEmpty) return legacy;
    return serviceName;
  }

  double get displayAmount {
    if (amount > 0) return amount;
    return 0;
  }

  factory Appointment.fromJson(Map<String, dynamic> json) {
    void addUnique(List<String> out, String? raw) {
      final value = (raw ?? '').trim();
      if (value.isEmpty || value == 'null' || out.contains(value)) return;
      out.add(value);
    }

    List<String> parseServiceIds(dynamic raw) {
      final ids = <String>[];

      void walk(dynamic node) {
        if (node == null) return;
        if (node is List) {
          for (final item in node) {
            walk(item);
          }
          return;
        }
        if (node is Map) {
          final map = Map<String, dynamic>.from(node);
          if (map.containsKey('service_id')) {
            addUnique(ids, '${map['service_id']}');
          } else if (map.containsKey('serviceId')) {
            addUnique(ids, '${map['serviceId']}');
          } else if (map.containsKey('id')) {
            addUnique(ids, '${map['id']}');
          } else if (map.containsKey('service')) {
            walk(map['service']);
          }
          return;
        }
        if (node is String) {
          final text = node.trim();
          if (text.isEmpty || text == 'null') return;
          if (text.startsWith('[') || text.startsWith('{')) {
            try {
              walk(jsonDecode(text));
              return;
            } catch (_) {}
          }
          for (final part in text.split(',')) {
            addUnique(ids, part);
          }
          return;
        }
        addUnique(ids, '$node');
      }

      walk(raw);
      return ids;
    }

    final service = json['service'];
    final staff = json['staff'];
    final customer = json['customer'];
    final branch = json['branch'];
    final rawAmount = json['amount'];
    final amt = rawAmount is num
        ? rawAmount.toDouble()
        : double.tryParse('$rawAmount') ?? 0;
    final parsedIds = <String>[];
    for (final key in const [
      'service_ids',
      'serviceIds',
      'appointment_services',
      'appointmentServices',
    ]) {
      for (final id in parseServiceIds(json[key])) {
        addUnique(parsedIds, id);
      }
    }
    final primaryId = '${json['service_id'] ?? service?['id'] ?? ''}'.trim();
    if (primaryId.isNotEmpty && primaryId != 'null' && !parsedIds.contains(primaryId)) {
      parsedIds.insert(0, primaryId);
    }
    return Appointment(
      id: '${json['id']}',
      customerName: '${json['customer_name'] ?? ''}',
      serviceName: '${service is Map ? service['name'] ?? '' : ''}',
      date: '${json['date'] ?? ''}',
      time: '${json['time'] ?? ''}',
      status: '${json['status'] ?? 'pending'}',
      createdBy: '${staff is Map ? staff['name'] ?? '' : ''}',
      serviceId: primaryId,
      serviceIds: parsedIds,
      branchId: '${json['branch_id'] ?? (branch is Map ? branch['id'] ?? '' : '')}',
      phone: '${json['phone'] ?? (customer is Map ? customer['phone'] ?? '' : '')}',
      notes: '${json['notes'] ?? ''}',
      amount: amt,
      staffId: '${json['staff_id'] ?? staff?['id'] ?? ''}',
      customerId: '${json['customer_id'] ?? customer?['id'] ?? ''}',
      branchName: '${branch is Map ? branch['name'] ?? '' : ''}',
    );
  }
}
