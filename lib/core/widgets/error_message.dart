import 'package:msu_wellbeing/core/network/api_exception.dart';
import 'package:msu_wellbeing/l10n/l10n.dart';

/// Plain-language messages for failures. Never shows technical details.
extension ErrorMessages on AppLocalizations {
  String describeError(Object? error) {
    final kind = error is ApiException ? error.kind : ApiExceptionKind.unknown;
    return switch (kind) {
      ApiExceptionKind.network => errorNetwork,
      ApiExceptionKind.timeout => errorTimeout,
      ApiExceptionKind.unauthorized => errorUnauthorized,
      ApiExceptionKind.forbidden => errorForbidden,
      ApiExceptionKind.invalidInput => errorInvalidInput,
      ApiExceptionKind.notFound => errorNotFound,
      ApiExceptionKind.server || ApiExceptionKind.unknown => errorGeneric,
    };
  }
}
