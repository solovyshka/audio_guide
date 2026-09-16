# audio_guide

Плеер готовых аудиогидов: Flutter-приложение и API. Генерация гидов живёт отдельно.

## Где крутится

- **FIREBAT** (коробка): код, контент и `audio-guide.service` — `/opt/audio_guide`, uvicorn `127.0.0.1:8090`. Секреты: `/opt/secrets/audio_guide/.env`.
- **Снаружи:** OVH `http://51.254.219.211` (nginx :80 → SSH :2222 → FIREBAT). MegaFon режет Cloudflare с коробки, поэтому туннель `audio.solovyshka.com` с FIREBAT не используем.
- На OVH: юнит `audio-guide-wan.service`. API читает `content/catalog.json` с диска. Postgres в схеме есть, в рантайме не нужен.

На FIREBAT: `git pull` → `sudo systemctl restart audio-guide`. Не править файлы руками (кроме секретов).

**Не класть в git:** `.env`, пароль Postgres, ключ админки, ключ MapKit. Большие mp3 лучше держать только на диске, в git — JSON; wav тестовых пакетов пока в репозитории.

## Ключи и что платное

Сейчас для плеера нужен один внешний ключ:

| Что | Зачем | Деньги |
|---|---|---|
| **MapKit Mobile SDK** | Карта и пины в приложении | Бесплатно на старте (около 1000 DAU / до 25k MAU в зависимости от оферты). Платно, если приложение станет массовым или платным в сторе |
| Postgres | На FIREBAT, пока не используется API | Своё железо |
| OVH VPS | Публичный HTTP, обход MegaFon | Уже есть |

Ключ MapKit: [Кабинет разработчика](https://developer.tech.yandex.ru/) → подключить MapKit Mobile SDK. Локально скопируйте `app/lib/secrets.example.dart` в `app/lib/secrets.dart` (файл в git не попадает) и вставьте ключ. На FIREBAT тот же ключ — `~/.local/share/audio_guide/mapkit.env`. Без ключа карта всё равно рисуется (OSM). Либо так:

```
flutter run --dart-define=MAPKIT_API_KEY=ключ --dart-define=API_BASE=http://51.254.219.211
```

**Пока не нужны и не тарифицируются** (это контур генерации, не плеер):

- SpeechKit TTS — по запросам синтеза
- YandexGPT — по токенам
- Places API — по запросам поиска организаций

Системный STT в телефоне бесплатный. Тестовая озвучка Коломны уже лежит в репозитории.

## Запуск API на FIREBAT

```
sudo bash /opt/audio_guide/deploy/install.sh
```

Python — 3.12 (`~/.local/bin/python3.12`). Проверка:

```
curl -sS http://127.0.0.1:8090/health
curl -sS "http://51.254.219.211/guides/search?q=коломна"
```

Секреты: `bash /opt/audio_guide/deploy/secrets/apply-local.sh audio_guide /opt/audio_guide audio-guide`.

## Локальная машина (Windows)

Версии SDK, PATH и env на этом ПК: [docs/windows-dev-machine.md](docs/windows-dev-machine.md).

## Приложение

Сборка APK на FIREBAT (после тулчейна):

```
bash /opt/audio_guide/deploy/install-android-toolchain.sh   # один раз
bash /opt/audio_guide/deploy/build-apk.sh
```

Готовый файл: `http://51.254.219.211/app/audio_guide.apk`. В приложении, если на сервере больший `versionCode`, появляется кнопка «Обновить». Первый раз APK ставится вручную; дальше — эта кнопка. Подпись одна и та же (keystore у `solovyshka` на FIREBAT). Старый APK с Windows (debug-ключ) один раз удалить и поставить заново.

Локально: `cd app && flutter build apk --release` — копия в корень репозитория `audio_guide.apk`.
