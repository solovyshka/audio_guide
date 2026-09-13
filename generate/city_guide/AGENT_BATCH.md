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

1. Выбери вариант:
   - `short`: 8–15 точек в одном компактном пешем кластере;
   - `long`: 15–30 точек, несколько районов и переезды только при необходимости.
   Для API: `python -m generate.city_guide api --variant long <город>`.
   Длинный пакет получает id `<город>-long`; короткий — обычный id города.
2. `python -m generate.city_guide list-cities` — следующий без `#`.
3. Research → `content/guides/{id}/{id}.research.json` (схема `CityResearch`, поля `disputed`, `next_leg`).
4. Writer → черновик `guide.json` (спорное с «— неизвестно»). Для переезда заполняй `next_leg` только проверенной инструкцией.
5. ```
   python -m generate.city_guide normalize-write --research ... --guide ...
   python -m generate.city_guide validate ...research.json .../guide.json
   ```
   Для длинного варианта добавь `--package-id <город>-long` к `normalize-write`.
6. Пока `valid: false` — правь только `text` / intro, снова validate.
7. В `cities.txt`: `# done: Город`.

## Не делать в этом цикле

- TTS и upload на сервер — только по отдельной просьбе.
- Не переписывать Коломну без запроса.
- Не выдумывать координаты: только из источников в research.
