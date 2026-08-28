import 'package:cloud_firestore/cloud_firestore.dart';

abstract class DataAggregator {
  Future<void> aggregate(DocumentReference shopRef);
}
