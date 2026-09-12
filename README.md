# audio_guide

Плеер готовых аудиогидов: Flutter-приложение и API на `161.104.53.72`. Генерация гидов живёт отдельно.

## Git на сервере

Да, папку на сервере стоит держать как **клона этого репозитория**, а не как вторую правду.

- Код и пакеты гидов (`server/`, `app/`, `content/`) — в git. На сервере: `git clone` → `git pull` → рестарт сервиса.
- Не править файлы руками на сервере (кроме секретов). Иначе рассинхрон.
- **Не класть в git:** `.env`, пароль Postgres, ключ админки, ключ MapKit.
- Аудио тестового гида сейчас в git (`content/guides/kolomna/audio/`). Когда генератор начнёт заливать большие mp3, их лучше хранить только на диске сервера, а в git оставлять JSON.

Предлагаемый путь: `/opt/audio_guide`.

## Ключи и что платное

Сейчас для плеера нужен один внешний ключ:

| Что | Зачем | Деньги |
|---|---|---|
| **MapKit Mobile SDK** | Карта и пины в приложении | Бесплатно на старте (около 1000 DAU / до 25k MAU в зависимости от оферты). Платно, если приложение станет массовым или платным в сторе |
| Postgres | Уже стоит на сервере | Входит в VPS |
| VPS `161.104.53.72` | API и файлы | Уже оплачивается |

Ключ MapKit: [Кабинет разработчика](https://developer.tech.yandex.ru/) → подключить MapKit Mobile SDK. Локально скопируйте `app/lib/secrets.example.dart` в `app/lib/secrets.dart` (файл в git не попадает) и вставьте ключ. Либо так:

```
flutter run --dart-define=MAPKIT_API_KEY=ключ --dart-define=API_BASE=http://161.104.53.72
```

**Пока не нужны и не тарифицируются** (это контур генерации, не плеер):

- SpeechKit TTS — по запросам синтеза
- YandexGPT — по токенам
- Places API — по запросам поиска организаций

Системный STT в телефоне бесплатный. Тестовая озвучка Коломны уже лежит в репозитории.

## Запуск API

На сервере, после клона:

```
cd /opt/audio_guide/server
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt
cp .env.example .env   # прописать пароль БД и ADMIN_API_KEY
sudo -u postgres psql YOUR_DB -f schema.sql
.venv/bin/uvicorn app.main:app --host 127.0.0.1 --port 8000
```

Юнит и nginx: `deploy/audio-guide.service`, `deploy/nginx.conf`. Снаружи сейчас открыт только SSH — для API нужно открыть 80 и повесить nginx.

Пока Postgres можно не подключать: API читает `content/catalog.json` и отдаёт Коломну.

Проверка: `GET http://161.104.53.72/guides/search?q=коломна`

## Локальная машина (Windows)

Версии SDK, PATH и env на этом ПК: [docs/windows-dev-machine.md](docs/windows-dev-machine.md).

## Приложение

Android-папка уже сгенерирована. Сборка:

```
cd app
flutter build apk --release
```

Если поднимаете проект с нуля, нужен Flutter SDK, затем:

```
cd app
flutter create . --project-name audio_guide --org com.solovyshka --platforms=android,ios
```

В `android/app/src/main/AndroidManifest.xml` нужны интернет, микрофон и cleartext (HTTP на IP):

```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.RECORD_AUDIO"/>
<application android:usesCleartextTraffic="true" ...>
```
