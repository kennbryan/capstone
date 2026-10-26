import 'package:msu_wellbeing/core/utils/result.dart';
import 'package:msu_wellbeing/features/onboarding/domain/entities/consent_record.dart';

/// Stores consent decisions (oldest first).
abstract interface class ConsentRepository {
  Future<Result<List<ConsentRecord>>> loadHistory();

  /// Appends [record] to the history.
  Future<Result<ConsentRecord>> record(ConsentRecord record);
}
