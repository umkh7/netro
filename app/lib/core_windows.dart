// Ядро Xray на Windows: libXray.dll через FFI (тот же Invoke API, что на Android).
import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:ffi/ffi.dart';

typedef _InvokeC = Pointer<Utf8> Function(Pointer<Utf8>);
typedef _FreeC = Void Function(Pointer<Utf8>);
typedef _FreeD = void Function(Pointer<Utf8>);

class _Lib {
  static _Lib? _i;
  final _InvokeC invoke;
  final _FreeD free;
  _Lib(this.invoke, this.free);

  static _Lib get i {
    if (_i != null) return _i!;
    final dir = File(Platform.resolvedExecutable).parent.path;
    final lib = DynamicLibrary.open('$dir\\libXray.dll');
    _i = _Lib(
      lib.lookupFunction<Pointer<Utf8> Function(Pointer<Utf8>), _InvokeC>(
        'CGoInvoke',
      ),
      lib.lookupFunction<_FreeC, _FreeD>('CGoFree'),
    );
    return _i!;
  }
}

String _invokeSync(String request) {
  final lib = _Lib.i;
  final req = request.toNativeUtf8();
  try {
    final res = lib.invoke(req);
    if (res.address == 0) return '{"success":false,"error":"empty response"}';
    final s = res.toDartString();
    lib.free(res);
    return s;
  } finally {
    calloc.free(req);
  }
}

/// Вызов в отдельном изоляте, чтобы долгие операции (пинг) не тормозили интерфейс.
Future<String> winInvoke(String request) =>
    Isolate.run(() => _invokeSync(request));

// ---------- Системный прокси Windows (WinINet) ----------

const _inetKey =
    r'HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings';

typedef _SetOptC = Int32 Function(Pointer<Void>, Uint32, Pointer<Void>, Uint32);
typedef _SetOptD = int Function(Pointer<Void>, int, Pointer<Void>, int);

void _refreshInet() {
  try {
    final wininet = DynamicLibrary.open('wininet.dll');
    final f = wininet.lookupFunction<_SetOptC, _SetOptD>('InternetSetOptionW');
    f(nullptr, 39, nullptr, 0); // INTERNET_OPTION_SETTINGS_CHANGED
    f(nullptr, 37, nullptr, 0); // INTERNET_OPTION_REFRESH
  } catch (_) {}
}

Future<void> setSystemProxy(String hostPort) async {
  await Process.run('reg', [
    'add',
    _inetKey,
    '/v',
    'ProxyServer',
    '/t',
    'REG_SZ',
    '/d',
    hostPort,
    '/f',
  ]);
  await Process.run('reg', [
    'add',
    _inetKey,
    '/v',
    'ProxyOverride',
    '/t',
    'REG_SZ',
    '/d',
    'localhost;127.*;10.*;172.16.*;172.17.*;172.18.*;172.19.*;172.2*;172.30.*;172.31.*;192.168.*;<local>',
    '/f',
  ]);
  await Process.run('reg', [
    'add',
    _inetKey,
    '/v',
    'ProxyEnable',
    '/t',
    'REG_DWORD',
    '/d',
    '1',
    '/f',
  ]);
  _refreshInet();
}

Future<void> clearSystemProxy() async {
  await Process.run('reg', [
    'add',
    _inetKey,
    '/v',
    'ProxyEnable',
    '/t',
    'REG_DWORD',
    '/d',
    '0',
    '/f',
  ]);
  _refreshInet();
}

/// Включён ли сейчас именно наш прокси (на случай аварийного закрытия).
Future<bool> ourProxyIsSet(String hostPort) async {
  final r = await Process.run('reg', ['query', _inetKey, '/v', 'ProxyServer']);
  final e = await Process.run('reg', ['query', _inetKey, '/v', 'ProxyEnable']);
  return (r.stdout as String).contains(hostPort) &&
      (e.stdout as String).contains('0x1');
}
