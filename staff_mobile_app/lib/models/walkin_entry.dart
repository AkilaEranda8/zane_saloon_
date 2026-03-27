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

  factory WalkInEntry.fromJson(Map<String, dynamic> json) {
    final service = json['service'] is Map ? Map<String, dynamic>.from(json['service']) : const <String, dynamic>{};
    final staff = json['staff'] is Map ? Map<String, dynamic>.from(json['staff']) : const <String, dynamic>{};
    return WalkInEntry(
      id: '${json['id'] ?? ''}',
      token: '${json['token'] ?? ''}',
      customerName: '${json['customer_name'] ?? ''}',
      phone: '${json['phone'] ?? ''}',
      status: '${json['status'] ?? 'waiting'}',
      branchId: '${json['branch_id'] ?? ''}',
      serviceId: '${json['service_id'] ?? service['id'] ?? ''}',
      serviceName: '${service['name'] ?? ''}',
      staffId: '${json['staff_id'] ?? staff['id'] ?? ''}',
      staffName: '${staff['name'] ?? ''}',
      estimatedWait: int.tryParse('${json['estimated_wait'] ?? 0}') ?? 0,
      note: '${json['note'] ?? ''}',
    );
  }
}
