import 'package:equatable/equatable.dart';

import '../ids.dart';

/// Journal entity and fields of the answer to a share to classify
/// (specification, 4.2 and chapter 6, « LineYearCategory »; decision H5 of
/// phase 4): where the shares of a line that fall in a year go, when that
/// year has no category of the same name as the line's.
abstract final class ShareClassificationFields {
  static const entity = 'shareClassification';
  static const lineId = 'lineId';
  static const year = 'year';

  /// The category chosen in the tree of [year].
  static const categoryId = 'categoryId';

  /// The category the line had when the answer was given: the answer holds
  /// only while the line keeps it.
  static const originCategoryId = 'originCategoryId';
}

/// The answer given for the shares of the line [lineId] that fall in [year].
class ShareClassification extends Equatable {
  const ShareClassification({
    required this.id,
    required this.lineId,
    required this.year,
    required this.categoryId,
    required this.originCategoryId,
  });

  final String id;
  final String lineId;
  final int year;
  final String categoryId;
  final String originCategoryId;

  @override
  List<Object?> get props => [id, lineId, year, categoryId, originCategoryId];
}

/// Identifier of the answer for the line [lineId] in [year]: computed, so
/// that two devices answering the same question write the same record
/// (principle 7).
String shareClassificationId(String lineId, int year) => derivedId('share-classification/$lineId/$year');
