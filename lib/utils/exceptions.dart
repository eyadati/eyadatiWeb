import 'package:easy_localization/easy_localization.dart';

class AppException implements Exception {
  final String message;
  final String? code;

  AppException(this.message, {this.code});

  @override
  String toString() => message;

  String get localizedMessage => message.tr();
}

class NetworkException extends AppException {
  NetworkException() : super('no_internet_connection', code: 'network_error');
}

class AuthException extends AppException {
  AuthException(super.message) : super(code: 'auth_error');
}

class DatabaseException extends AppException {
  DatabaseException(super.message) : super(code: 'database_error');
}
