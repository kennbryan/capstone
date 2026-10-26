import 'package:freezed_annotation/freezed_annotation.dart';

part 'consent_record.freezed.dart';

/// What the user agrees to.
enum ConsentScope {
  /// Required: process my data so the app works.
  processData,

  /// Optional: let the assistant use my latest report summary.
  personalizeWithReport;

  bool get isRequired => this == ConsentScope.processData;
}

/// One consent decision. Changes append a new record, so the history
/// shows every grant and withdrawal.
@freezed
abstract class ConsentRecord with _$ConsentRecord {
  const factory({
    required int version,
    required Set<ConsentScope> grantedScopes,
    required DateTime grantedAt,
  }) = _ConsentRecord;
  const new _();

  bool get coversRequired => grantedScopes.contains(ConsentScope.processData);

  /// Whether this record still satisfies the current [requiredVersion].
  bool isValidFor(int requiredVersion) =>
      coversRequired && version >= requiredVersion;
}
