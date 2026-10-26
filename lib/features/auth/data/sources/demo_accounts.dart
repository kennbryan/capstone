import 'package:msu_wellbeing/features/auth/data/models/user_dto.dart';

/// A demo account that signs in on the device, without the backend.
///
/// They exist so the team and reviewers can enter the app before the
/// backend has real accounts. Turned off with `DEMO_LOGIN=false`, and
/// `AppConfig.validate` refuses a `prod` build that still has them on.
/// After signing in, data screens (rapor, check-in, chat) call the backend
/// like for any user.
class DemoAccount {
  const new({
    required this.id,
    required this.email,
    required this.password,
    required this.displayName,
    required this.persona,
  });

  final String id;
  final String email;
  final String password;
  final String displayName;

  /// Short description shown in the demo picker.
  final String persona;
}

/// Shared password for every demo account.
const demoPassword = 'MsuDemo#2026';

/// The five demo accounts.
const demoAccounts = [
  DemoAccount(
    id: 'usr_demo_rani',
    email: 'rani@msu.demo',
    password: demoPassword,
    displayName: 'Rani',
    persona: 'Mahasiswi tingkat 2',
  ),
  DemoAccount(
    id: 'usr_demo_dimas',
    email: 'dimas@msu.demo',
    password: demoPassword,
    displayName: 'Dimas',
    persona: 'Mahasiswa tingkat akhir',
  ),
  DemoAccount(
    id: 'usr_demo_aisyah',
    email: 'aisyah@msu.demo',
    password: demoPassword,
    displayName: 'Aisyah',
    persona: 'Mahasiswi baru',
  ),
  DemoAccount(
    id: 'usr_demo_budi',
    email: 'budi@msu.demo',
    password: demoPassword,
    displayName: 'Pak Budi',
    persona: 'Jamaah MSU',
  ),
  DemoAccount(
    id: 'usr_demo_salsa',
    email: 'salsa@msu.demo',
    password: demoPassword,
    displayName: 'Bu Salsa',
    persona: 'Dosen dan civitas akademika',
  ),
];

/// Prefix of the device-only tokens given to demo sessions.
const _demoTokenPrefix = 'demo-session-';

/// Whether [token] belongs to a demo session.
bool isDemoToken(String token) => token.startsWith(_demoTokenPrefix);

/// The session created on the device for a demo [account].
LoginResponseDto demoLoginResponse(DemoAccount account) => LoginResponseDto(
  accessToken: '$_demoTokenPrefix${account.id}',
  refreshToken: '$_demoTokenPrefix${account.id}',
  user: UserDto(
    id: account.id,
    displayName: account.displayName,
    email: account.email,
  ),
);

/// The demo account matching [email] and [password], or null.
DemoAccount? findDemoAccount(String email, String password) {
  final normalized = email.trim().toLowerCase();
  for (final account in demoAccounts) {
    if (account.email == normalized && account.password == password) {
      return account;
    }
  }
  return null;
}
