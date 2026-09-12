Тестовые пакеты аудиогидов.

Раскладка совпадает с контрактом плеера: `catalog.json` — индекс, `guides/{id}/guide.json` — точки и тексты, `guides/{id}/audio/` — mp3.

Озвучка тестового пакета — встроенный голос Windows:

```
powershell -File content/scripts/tts_sapi.ps1
```

Более живой голос, когда есть Python:

```
python -m pip install edge-tts mutagen
python content/scripts/tts_from_guide.py content/guides/kolomna/guide.json
```
