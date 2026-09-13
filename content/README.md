Тестовые пакеты аудиогидов.

Раскладка совпадает с контрактом плеера: `catalog.json` — индекс, `guides/{id}/guide.json` — точки и тексты, `guides/{id}/audio/` — mp3.

Озвучка — отдельный кусок пайплайна, `python -m generate.tts`.

Сравнить движки на абзаце Коломны:

```
python -m pip install -r generate/requirements-tts.txt
python -m generate.tts list
python -m generate.tts sample --backends edge,sapi
```

Озвучить весь гид в `generate/out/` (исходную Коломну не перезаписывает):

```
python -m generate.tts guide content/guides/kolomna/guide.json --backend edge
```

Старые скрипты `content/scripts/tts_sapi.ps1` и `tts_from_guide.py` ещё работают.
