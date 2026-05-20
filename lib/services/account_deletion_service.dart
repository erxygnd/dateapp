import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AccountDeletionService {
  AccountDeletionService({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : auth = auth ?? FirebaseAuth.instance,
      firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth auth;
  final FirebaseFirestore firestore;

  Future<void> reauthenticateWithPassword(String password) async {
    final user = auth.currentUser;
    final email = user?.email;

    if (user == null || email == null || email.isEmpty) {
      throw FirebaseAuthException(
        code: 'missing-email',
        message: 'Hesap silme icin oturum bilgisi bulunamadi.',
      );
    }

    final credential = EmailAuthProvider.credential(
      email: email,
      password: password,
    );
    await user.reauthenticateWithCredential(credential);
  }

  Future<void> deleteCurrentAccount() async {
    final user = auth.currentUser;

    if (user == null) {
      throw FirebaseAuthException(
        code: 'missing-user',
        message: 'Silinecek oturum bulunamadi.',
      );
    }

    final uid = user.uid;
    final userDoc = await firestore.collection('users').doc(uid).get();
    final usernameLower = userDoc.data()?['usernameLower']?.toString();

    await _removeUserMessages(uid);
    await _deleteQuery(
      firestore.collection('blocks').where('blockerId', isEqualTo: uid),
    );
    await _deleteQuery(
      firestore
          .collection('interest_requests')
          .where('interestedUserId', isEqualTo: uid),
    );
    await _deleteQuery(
      firestore
          .collection('interest_requests')
          .where('postOwnerId', isEqualTo: uid),
    );
    await _deleteQuery(
      firestore.collection('encounters').where('ownerId', isEqualTo: uid),
    );
    await _deleteQuery(
      firestore.collection('reports').where('reporterId', isEqualTo: uid),
    );
    if (usernameLower != null && usernameLower.isNotEmpty) {
      await firestore.collection('usernames').doc(usernameLower).delete();
    }
    await firestore.collection('users').doc(uid).delete();
    await user.delete();
  }

  Future<void> _removeUserMessages(String uid) async {
    final chats = await firestore
        .collection('chats')
        .where('participants', arrayContains: uid)
        .get();

    for (final chat in chats.docs) {
      await _deleteQuery(
        chat.reference.collection('messages').where('senderId', isEqualTo: uid),
      );
      await chat.reference.set({
        'participantNames': {uid: 'Silinmis kullanici'},
        'deletedParticipants': FieldValue.arrayUnion([uid]),
        'lastMessage': 'Bir kullanici hesabini sildi.',
        'lastMessageAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  Future<void> _deleteQuery(Query<Map<String, dynamic>> query) async {
    QuerySnapshot<Map<String, dynamic>> snapshot;

    do {
      snapshot = await query.limit(400).get();

      if (snapshot.docs.isEmpty) {
        return;
      }

      final batch = firestore.batch();

      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
    } while (snapshot.docs.length == 400);
  }
}
