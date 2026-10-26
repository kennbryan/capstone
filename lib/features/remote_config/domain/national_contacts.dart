import 'package:msu_wellbeing/features/remote_config/domain/entities/remote_config.dart';

/// Verified national help lines (checked October 2026 against Kemenkes and
/// national 112 information). They are shown whenever the server sends no
/// crisis contacts or cannot be reached, so the crisis screen is never
/// empty. DKMSU can add campus contacts through `/config`.
const nationalCrisisContacts = [
  CrisisContact(
    label: 'Healing119 (Kemenkes)',
    phone: '119',
    description: 'Dukungan kesehatan jiwa 24 jam. Setelah tersambung, tekan 8.',
  ),
  CrisisContact(
    label: 'Darurat umum',
    phone: '112',
    description: 'Panggilan darurat nasional, bebas pulsa.',
  ),
  CrisisContact(
    label: 'Ambulans',
    phone: '118',
    description: 'Gawat darurat medis.',
  ),
];
