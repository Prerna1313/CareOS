import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/memory_item.dart';
import 'firestore_service.dart';

class FirestoreMemoryService extends FirestoreService {
  static const String collectionPath = 'memory_items';

  Future<void> syncMemoryItem(MemoryItem item) async {
    final uid = userId;
    if (uid == null) return;

    final path = 'users/$uid/$collectionPath/${item.id}';
    
    final data = item.toMap();
    data['lastUpdated'] = FieldValue.serverTimestamp();
    
    await setData(
      path: path,
      data: data,
    );
  }

  Future<void> deleteMemoryItem(String id) async {
    final uid = userId;
    if (uid == null) return;

    final path = 'users/$uid/$collectionPath/$id';
    await deleteData(path: path);
  }

  Stream<List<MemoryItem>> getMemoriesStream() {
    final uid = userId;
    if (uid == null) return Stream.value([]);

    return collectionStream<MemoryItem>(
      path: 'users/$uid/$collectionPath',
      builder: (data, _) => MemoryItem.fromMap(data),
      queryBuilder: (query) => query.orderBy('createdAt', descending: true),
    );
  }

  Future<List<MemoryItem>> getAllMemories() async {
    final uid = userId;
    if (uid == null) return [];

    final snapshot = await getCollection('users/$uid/$collectionPath').get();
    return snapshot.docs.map((doc) {
      return MemoryItem.fromMap(doc.data() as Map<String, dynamic>);
    }).toList();
  }
}
