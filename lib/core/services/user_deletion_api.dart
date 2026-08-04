export 'user_deletion_api_stub.dart' show UserDeletionApiException;
export 'user_deletion_api_stub.dart'
    if (dart.library.html) 'user_deletion_api_web.dart'
    if (dart.library.io) 'user_deletion_api_io.dart';
