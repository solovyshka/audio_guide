# Что установлено на этой Windows-машине

Снято 12 сентября 2026. Это локальный стек **этого ПК**, не сервера `161.104.53.72`.

После правок PATH откройте **новый** терминал (или Cursor), иначе старая сессия не увидит Python.

## ОС и железо

| Что | Версия / путь |
|---|---|
| Windows | 10 (build 19045) |
| GPU | NVIDIA GeForce RTX 2080 SUPER, 8 GB |
| Драйвер NVIDIA | 580.88 |
| CUDA (по драйверу) | 13.0 |

## User environment

| Переменная | Значение |
|---|---|
| `JAVA_HOME` | `C:\Users\user\develop\jdk-21` |
| `ANDROID_HOME` | `C:\Users\user\AppData\Local\Android\Sdk` |
| `ANDROID_SDK_ROOT` | то же, что `ANDROID_HOME` |
| `FLUTTER_ROOT` | `C:\Users\user\develop\flutter` |
| `PY_PYTHON` | `3.12` |
| `PYTHONUTF8` | `1` |
| `PYTHONHOME` | **не задавать** — ломает venv |

## User PATH (порядок важен)

1. `C:\Users\user\AppData\Local\Programs\Python\Python312`
2. `C:\Users\user\AppData\Local\Programs\Python\Python312\Scripts`
3. `C:\Users\user\AppData\Local\Programs\Python\Launcher`
4. `C:\Users\user\develop\flutter\bin`
5. `C:\Users\user\develop\jdk-21\bin`
6. `C:\Users\user\AppData\Local\Android\Sdk\platform-tools`
7. `C:\Users\user\AppData\Local\Android\Sdk\cmdline-tools\latest\bin`
8. дальше — Cursor, WindowsApps, PyCharm, WinGet Links

Заглушка `WindowsApps\python.exe` остаётся в PATH, но **после** настоящего Python, поэтому `python` в новом терминале — 3.12.10.

## Python

| Что | Версия | Путь |
|---|---|---|
| CPython (основной) | **3.12.10** | `C:\Users\user\AppData\Local\Programs\Python\Python312\python.exe` |
| pip | 25.0.1 | тот же префикс |
| `py` launcher | 3.12 по умолчанию (`PY_PYTHON=3.12`) | `...\Python\Launcher` |
| uv / Astral (дополнительно) | CPython 3.12.11 | `C:\Users\user\AppData\Roaming\uv\python\cpython-3.12.11-windows-x86_64-none\python.exe` |

Команды: `python`, `python -m pip`, `py`. Для проекта сервера лучше venv, не глобальный pip.

## Flutter / Dart

| Что | Версия | Путь |
|---|---|---|
| Flutter | 3.47.4 stable | `C:\Users\user\develop\flutter` |
| Dart | 3.13.3 | идёт с Flutter |
| DevTools | 2.60.0 | идёт с Flutter |
| Framework rev | `9584c6713b` (2026-09-10) | |

Сборка APK:

```
cd C:\Users\user\Desktop\AI_projects\Audio_guide\audio_guide\app
flutter build apk --release
```

Готовый файл копируется в корень репозитория: `audio_guide.apk` (git его не берёт). Исходник сборки: `app\build\app\outputs\flutter-apk\`.

## Java

| Что | Версия | Путь |
|---|---|---|
| Microsoft OpenJDK (рабочий) | **21.0.12 LTS** (`21.0.12+8-LTS`) | `C:\Users\user\develop\jdk-21` |

JDK 17 ставился через winget в `C:\Program Files\Microsoft\jdk-17.0.20.101-hotspot`, на диске его уже нет. Из User PATH убран. Для Flutter + MapKit нужен **21** (плагин Яндекса собран под class file 65).

## Android SDK

Корень: `C:\Users\user\AppData\Local\Android\Sdk`

| Пакет | Версия |
|---|---|
| Command-line Tools | 12.0 (`cmdline-tools\latest`) |
| Platform-tools / adb | 37.0.1 (adb 1.0.41) |
| Platforms | android-34, android-35, android-36 |
| Build-tools | 36.0.0 |
| NDK | 28.2.13676358 (r28c) |
| CMake | 3.22.1 |
| Gradle (wrapper проекта) | 9.3.1 |

Приложение: `applicationId` `com.solovyshka.audio_guide`, minSdk 26, compileSdk 36.

## Прочее уже на машине

| Что | Версия / путь |
|---|---|
| Git | 2.55.0.windows.2 — `C:\Program Files\Git\cmd` |
| PyCharm | 2026.1.4 — `C:\Program Files\JetBrains\PyCharm 2026.1.4` |
| Cursor | `C:\Users\user\AppData\Local\Programs\cursor` |
| .NET | в Machine PATH (`C:\Program Files\dotnet\`) |
| NVIDIA PhysX / NvDLISR | Machine PATH |

Не ставили отдельный Android Studio: SDK качался cmdline-tools + Flutter.

## Сервер (не этот ПК)

API и контент: `161.104.53.72` (`brynn`). Код: `/opt/audio_guide`. Python там — системный Linux, не этот Windows 3.12.
