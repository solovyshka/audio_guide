export 'mapkit_init_native.dart'
    if (dart.library.html) 'mapkit_init_stub.dart'
    if (dart.library.js_interop) 'mapkit_init_stub.dart';
