# Батч аудиогидов из чата Cursor

Агент (GPT-terra и др.) генерирует текст по промптам из `prompts.py`.
Поиск — через WebSearch/WebFetch. QA — команда `validate` в цикле.

## Старт

```text
Собери аудиогид по очереди из generate/cities.txt.
Один город за проход. Промпты: python -m generate.city_guide prompts agent
и prompts research / writer.
После текста: normalize-write, затем validate до OK.
```

## Цикл на город

1. `python -m generate.city_guide list-cities` — следующий без `#`.
2. Research → `content/guides/{id}/{id}.research.json` (схема `CityResearch`, поле `disputed`).
3. Writer → черновик `guide.json` (спорное с «— неизвестно»).
4. ```
   python -m generate.city_guide normalize-write --research ... --guide ...
   python -m generate.city_guide validate ...research.json .../guide.json
   ```
5. Пока `valid: false` — правь только `text` / intro, снова validate.
6. В `cities.txt`: `# done: Город`.

## Не делать в этом цикле

- TTS и upload на сервер — только по отдельной просьбе.
- Не переписывать Коломну без запроса.
- Не выдумывать координаты: только из источников в research.
