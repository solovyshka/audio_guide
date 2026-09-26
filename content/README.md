Тестовые пакеты аудиогидов.

Раскладка совпадает с контрактом плеера: `catalog.json` — индекс, `guides/{id}/guide.json` — точки и тексты, `guides/{id}/audio/` — wav/mp3 на сервере, в git не кладём.

## Текст гида (новый город)

Промпты и схемы: `generate/city_guide/`. Очередь: `generate/cities.txt`.
Сценарий для агента в чате: `generate/city_guide/AGENT_BATCH.md`.

```
python -m pip install -r generate/requirements-guide.txt
python -m generate.city_guide prompts research --length short
python -m generate.city_guide prompts writer --length long
python -m generate.city_guide list-cities
python -m generate.city_guide validate path/to/research.json path/to/guide.json
python -m generate.city_guide normalize-write --research ... --guide ...
```

Опционально полный прогон на FIREBAT (OpenAI через HideMe OpenVPN + Silero):

```
sudo bash /opt/audio_guide/deploy/secrets/apply-local.sh audio_guide /opt/audio_guide
bash /opt/audio_guide/deploy/new-city.sh "Суздаль" long
```

Локально, если ключ уже в `generate/.env`:

```
python -m generate.city_guide api "Суздаль" --length short
python -m generate.city_guide api "Суздаль" --length long --no-tts
```

## Общий гид небольшой страны

Страна хранит ту же публичную структуру, что и город: `history`, `present`,
`sights`, `nature`, `culture`, `leisure`. История и современная справка длиннее,
а подборки покрывают всю страну. Один общий маршрут задаётся через
`overviewGuideId` в `content/areas/{id}/area.json`.

Сборка Кипра без переозвучки:

```
python -m generate.city_guide country cyprus --no-tts
```

Полная сборка с Silero или обновление досье через OpenAI:

```
python -m generate.city_guide country cyprus --name "Кипр" --backend silero --voice xenia
python -m generate.city_guide country cyprus --name "Кипр" --refresh-dossier --no-tts
```

Команда проверяет шесть разделов, исследование и общий гид, обновляет каталог,
при необходимости создаёт аудио и всегда пересобирает офлайн-пакет приложения.

## Озвучка

```
python -m pip install -r generate/requirements-tts.txt
python -m generate.tts list
python -m generate.tts sample --backends edge,sapi
python -m generate.tts guide content/guides/kolomna/guide.json --backend silero --voice xenia
```

`guide` пишет в `generate/out/` и не затирает исходный пакет, если не указать `--out-dir`.

Старые скрипты `content/scripts/tts_sapi.ps1` и `tts_from_guide.py` ещё работают.
