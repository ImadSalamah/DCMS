// This file conditionally exports the correct face recognition page for each platform.
// Usage: import 'face_recognition_online_page.dart';

export 'face_recognition_online_page_web.dart'
    if (dart.library.io) 'face_recognition_online_page_mobile.dart'
    if (dart.library.html) 'face_recognition_online_page_web.dart'
    if (dart.library.io) 'face_recognition_online_page_mobile.dart'
        'face_recognition_online_page_stub.dart';
