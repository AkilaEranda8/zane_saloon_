/// One row from GET /api/staff/commission (branch / all-branch summary).
class StaffCommissionSummary {
  StaffCommissionSummary({
    required this.staffId,
    required this.staffName,
    required this.role,
    required this.branchName,
    required this.appointmentCount,
    required this.totalRevenue,
    required this.totalCommission,
    this.commissionType,
    this.commissionValue,
  });

  final String staffId;
  final String staffName;
  final String role;
  final String branchName;
  final int appointmentCount;
  final double totalRevenue;
  final double totalCommission;
  final String? commissionType;
  final double? commissionValue;

  factory StaffCommissionSummary.fromJson(Map<String, dynamic> json) {
    final rev = json['totalRevenue'];
    final comm = json['totalCommission'];
    final cv = json['commissionValue'];
    return StaffCommissionSummary(
      staffId: '${json['staffId'] ?? ''}',
      staffName: '${json['staffName'] ?? ''}',
      role: '${json['role'] ?? ''}',
      branchName: '${json['branchName'] ?? ''}',
      appointmentCount: int.tryParse('${json['appointmentCount'] ?? 0}') ?? 0,
      totalRevenue: rev is num ? rev.toDouble() : double.tryParse('$rev') ?? 0,
      totalCommission:
          comm is num ? comm.toDouble() : double.tryParse('$comm') ?? 0,
      commissionType: json['commissionType']?.toString(),
      commissionValue: cv is num ? cv.toDouble() : double.tryParse('$cv'),
    );
  }
}
