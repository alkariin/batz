import 'package:equatable/equatable.dart';

import 'category.dart';

/// An inconsistency that merging the data of several devices can produce.
/// Never blocking: each one is listed in the tasks of the home screen and
/// corrected through the usual screens.
sealed class LedgerIssue extends Equatable {
  const LedgerIssue();
}

/// Several categories of one year's tree have the same name, which each
/// device checked only against its own data.
class DuplicateCategoryName extends LedgerIssue {
  const DuplicateCategoryName(this.year, this.categories);

  final int year;

  /// At least two, in tree order.
  final List<Category> categories;

  String get name => categories.first.name;

  @override
  List<Object?> get props => [year, categories];
}

/// Categories of a year detached from its tree, to move back (see
/// [CategoryForest]).
class DetachedCategories extends LedgerIssue {
  const DetachedCategories(this.year, this.heads);

  final int year;
  final List<DetachedCategory> heads;

  @override
  List<Object?> get props => [year, heads];
}
