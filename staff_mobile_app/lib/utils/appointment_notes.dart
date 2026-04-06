/// Mirrors web `AppointmentsPage.jsx` — extra services stored in notes.
class AppointmentNotes {
  AppointmentNotes._();

  static const String extraServicesPrefix = 'Additional services:';
  static const String packagePrefix       = 'Package:';

  static String stripAdditionalServicesLine(String notes) {
    return notes
        .split('\n')
        .where((line) => !line.trim().startsWith(extraServicesPrefix))
        .join('\n')
        .trim();
  }

  static String stripPackageLine(String notes) {
    return notes
        .split('\n')
        .where((line) => !line.trim().startsWith(packagePrefix))
        .join('\n')
        .trim();
  }

  static List<String> parseAdditionalServiceNames(String notes) {
    for (final line in notes.split('\n')) {
      if (line.trim().startsWith(extraServicesPrefix)) {
        return line
            .replaceFirst(extraServicesPrefix, '')
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
      }
    }
    return [];
  }

  static String combineNotes(String baseNotes, List<String> extraServiceNames) {
    final stripped = stripAdditionalServicesLine(baseNotes);
    final extraLine = extraServiceNames.isEmpty
        ? ''
        : '$extraServicesPrefix ${extraServiceNames.join(', ')}';
    return [stripped, extraLine].where((s) => s.isNotEmpty).join('\n');
  }

  /// Build full notes string including optional package line.
  static String combineNotesWithPackage({
    required String baseNotes,
    required List<String> extraServiceNames,
    String? packageId,
    String? packageName,
  }) {
    final stripped = stripPackageLine(stripAdditionalServicesLine(baseNotes));
    final pkgLine  = (packageId != null && packageId.isNotEmpty)
        ? '$packagePrefix #$packageId - ${packageName ?? 'Package'}'
        : '';
    final extraLine = extraServiceNames.isEmpty
        ? ''
        : '$extraServicesPrefix ${extraServiceNames.join(', ')}';
    return [stripped, pkgLine, extraLine].where((s) => s.isNotEmpty).join('\n');
  }
}
