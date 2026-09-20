# Батч аудиогидов из чата Cursor

Агент (GPT-terra и др.) генерирует текст по промптам из `prompts.py`.
Поиск — через WebSearch/WebFetch. QA — команда `validate` в цикле.

## Старт

```text
Собери аудиогид по очереди из generate/cities.txt.
Один город за проход. Формат: короткий (6–8 точек) или длинный (15–30).
Промпты: python -m generate.city_guide prompts research --length short|long
и prompts writer --length … После текста: normalize-write, затем validate до OK.
```

## Цикл на город

1. `python -m generate.city_guide list-cities` — следующий без `#`.
2. Research нужного формата → `content/guides/{id}/{id}.research.json`
   (длинный id = `{slug}-long`).
3. Writer → черновик `guide.json` (спорное с «— неизвестно»).
4. ```
   python -m generate.city_guide normalize-write --research ... --guide ...
   python -m generate.city_guide validate ...research.json .../guide.json
   ```
5. Пока `valid: false` — правь только `text` / intro, снова validate.
6. В `cities.txt`: `# done: Город`.

## Досуг (кафе, еда)

Не искать заведения в OSM. По умолчанию до 4 вывесок в каждом
направлении с рейтингом строго выше 4,5; меньше — если достойных нет.
Для большого города — больше, только если в задании сказано сколько.
Лестница по стране города (не по языку гида): местные → английские → русские.
На Кипре русские экспат-сайты — последние. Подробности:
`python -m generate.city_guide prompts leisure`.

## Места и природа

Те же карты и та же лестница по стране, не OSM и не память модели.
Места: категории достопримечательность / храм / памятник / кремль / башня.
Природа: парк / сквер / набережная и смотровая площадка (карточка или
особенность «Смотровая площадка»). Сколько есть достойных карточек
с рейтингом строго выше 3,9. «До 4» — только у досуга.
Башня без метки смотровой остаётся в Местах.
`python -m generate.city_guide prompts sights`
`python -m generate.city_guide prompts nature`.

## Не делать в этом цикле

- Не переписывать Коломну без запроса.
- Не выдумывать координаты: только из источников в research.

Полный серверный прогон (OpenAI через HideMe OpenVPN + Silero) на FIREBAT:

```
sudo bash /opt/audio_guide/deploy/secrets/apply-local.sh audio_guide /opt/audio_guide
bash /opt/audio_guide/deploy/new-city.sh "Город"
```
