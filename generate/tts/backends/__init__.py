from generate.tts.backends.edge import EdgeBackend
from generate.tts.backends.sapi import SapiBackend
from generate.tts.backends.silero import SileroBackend
from generate.tts.backends.yandex import YandexBackend

ALL_BACKENDS = {
    "edge": EdgeBackend,
    "sapi": SapiBackend,
    "silero": SileroBackend,
    "yandex": YandexBackend,
}
