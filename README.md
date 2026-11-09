# Netro

VPN-клиент для Android, Windows и iOS на ядре Xray.

- Интерфейс: Flutter (`app/`), один код на все платформы.
- Ядро: [Xray-core](https://github.com/XTLS/Xray-core) (MPL-2.0) через [libXray](https://github.com/XTLS/libXray) (MIT).
- Принимает подписки `https://…` и ключи vless, vmess, trojan, shadowsocks, hysteria2.
- Режимы: туннель (весь трафик через VPN) и локальный прокси (SOCKS5 `127.0.0.1:10808`, HTTP `127.0.0.1:10809`).
- Ключи хранятся только на устройстве.

## Сборка Android

```bash
./scripts/build_core_android.sh     # ядро → app/android/app/libs/libXray.aar
cd app && flutter build apk --release --target-platform android-arm,android-arm64
```

Подпись: файл `app/android/key.properties` (в git не хранится).

## Ссылка «Добавить в Netro»

`netro://add?url=<ссылка подписки в URL-кодировке>`
