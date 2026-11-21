import 'package:equatable/equatable.dart';

/// The ten account types. The name is what the journal stores.
enum AccountType { privateAccount, savings, pillar3, pillar2, investments, vehicle, rentDeposit, cash, debts, other }

/// Bank statement formats the server can read.
enum ImportFormat { postfinance }

/// Journal entity and fields of an account.
abstract final class AccountFields {
  static const entity = 'account';
  static const name = 'name';
  static const type = 'type';
  static const importFormat = 'importFormat';
  static const archived = 'archived';
}

class Account extends Equatable {
  const Account({required this.id, required this.name, required this.type, this.importFormat, this.archived = false});

  final String id;
  final String name;
  final AccountType type;

  /// The statement format, when import is enabled.
  final ImportFormat? importFormat;
  final bool archived;

  /// A detailed account is one whose transactions come from its bank
  /// statements: it is detailed if and only if import is enabled.
  bool get isDetailed => importFormat != null;

  @override
  List<Object?> get props => [id, name, type, importFormat, archived];
}

/// What the user enters to create or modify an account.
class AccountDraft {
  const AccountDraft({required this.name, required this.type, this.importFormat, this.archived = false});

  factory AccountDraft.of(Account account) => AccountDraft(
    name: account.name,
    type: account.type,
    importFormat: account.importFormat,
    archived: account.archived,
  );

  final String name;
  final AccountType type;
  final ImportFormat? importFormat;
  final bool archived;
}
