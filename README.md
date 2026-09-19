# audio_guide

Плеер готовых аудиогидов: Flutter-приложение и API. Генерация гидов живёт отдельно.

## Где крутится

- **FIREBAT** (коробка): код, контент и `audio-guide.service` — `/opt/audio_guide`, uvicorn `127.0.0.1:8090`. Секреты: `/opt/secrets/audio_guide/.env`.
- **Снаружи:** `https://audio.solovyshka.com` на OVH `51.254.219.211` (nginx :443/:80 → SSH-тоннель → FIREBAT). DNS у Cloudflare в режиме DNS only (серое облачко), A на OVH — без оранжевого прокси. Старые сборки ещё ходят на `http://51.254.219.211`.
- На OVH: юнит `audio-guide-wan.service`. API читает `content/catalog.json` с диска. Postgres в схеме есть, в рантайме не нужен.

На FIREBAT: `git pull` → `sudo systemctl restart audio-guide`. Не править файлы руками (кроме секретов).

**Не класть в git:** `.env`, пароль Postgres, ключ админки, ключ MapKit. Озвучка (`*.wav`, `*.mp3`) только на диске сервера; в git — JSON гидов.

## Ключи и что платное

Сейчас для плеера нужен один внешний ключ:

| Что | Зачем | Деньги |
|---|---|---|
| **MapKit Mobile SDK** | Карта и пины в приложении | Бесплатно на старте (около 1000 DAU / до 25k MAU в зависимости от оферты). Платно, если приложение станет массовым или платным в сторе |
| Postgres | На FIREBAT, пока не используется API | Своё железо |
| OVH VPS | Публичный HTTP, обход MegaFon | Уже есть |

Ключ MapKit: [Кабинет разработчика](https://developer.tech.yandex.ru/) → подключить MapKit Mobile SDK. Локально скопируйте `app/lib/secrets.example.dart` в `app/lib/secrets.dart` (файл в git не попадает) и вставьте ключ. На FIREBAT тот же ключ — `~/.local/share/audio_guide/mapkit.env`. Без ключа карта всё равно рисуется (OSM). Либо так:

```
flutter run --dart-define=MAPKIT_API_KEY=ключ --dart-define=API_BASE=https://audio.solovyshka.com
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
curl -sS "https://audio.solovyshka.com/guides/search?q=коломна"
```

Секреты: `bash /opt/audio_guide/deploy/secrets/apply-local.sh audio_guide /opt/audio_guide audio-guide`.

В приложении по пустому поиску можно нажать «Собрать аудиогид» — API на FIREBAT запускает тот же пайплайн в фоне.

## Новый город (текст + озвучка)

На FIREBAT OpenAI идёт через HideMe OpenVPN (split-tunnel только на `api.openai.com`, не полный шлюз). Ключ — в `/opt/secrets/audio_guide/.env`.

```
sudo bash /opt/audio_guide/deploy/secrets/apply-local.sh audio_guide /opt/audio_guide
bash /opt/audio_guide/deploy/new-city.sh "Сергиев Посад"
```

Пакет появится в `content/guides/{id}/` (json + wav) и в `catalog.json`. API его подхватит без рестарта.

## Локальная машина (Windows)

Версии SDK, PATH и env на этом ПК: [docs/windows-dev-machine.md](docs/windows-dev-machine.md).

## Приложение

Сборка APK на FIREBAT (после тулчейна):

```
bash /opt/audio_guide/deploy/install-android-toolchain.sh   # один раз
bash /opt/audio_guide/deploy/build-apk.sh
```

Готовый файл: страница [https://audio.solovyshka.com/app/](https://audio.solovyshka.com/app/). В приложении, если на сервере больший `versionCode`, появляется кнопка «Обновить». Первый раз ставится вручную; дальше — эта кнопка. Подпись одна и та же (keystore у `solovyshka` на FIREBAT). Старый APK с Windows (debug-ключ) один раз удалить и поставить заново.

Локально: `cd app && flutter build apk --release` — копия в корень репозитория `audio_guide.apk`.
