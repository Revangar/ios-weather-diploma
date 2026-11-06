# Внешний процессный offline harness

Эти файлы использованы только для диагностики Simulator на Mac автора. Они не входят в Xcode target, ресурсы приложения или Release. Обычные тесты и приложение работают без них. Сигнатура sandbox SPI сверена с [WebKit SandboxSPI.h](https://github.com/WebKit/WebKit/blob/main/Source/WTF/wtf/spi/darwin/SandboxSPI.h).

`compile_profile.c` — macOS-программа, компилирующая ограничение исходящих соединений с исключением localhost. `deny_network.c` — Simulator dylib, который читает этот профиль и применяет только к собственному процессу через sandbox_apply_bytecode. Путь к профилю зафиксирован для проверенного Mac; для воспроизведения на другом Mac требуется заменить его. Это не компонент пользовательского приложения и не поддерживаемый публичный iOS API.

Команды из корня родительского рабочего каталога:

```sh
xcrun --sdk macosx clang work/review-20261101/compile_profile.c -lsandbox -o work/review-20261101/compile_profile
work/review-20261101/compile_profile work/review-20261101/deny-network.sb.bin
xcrun --sdk iphonesimulator clang -arch arm64 -mios-simulator-version-min=17.0 -dynamiclib work/review-20261101/deny_network.c -o work/review-20261101/deny_network.dylib
```

Проверка выполняется только в отдельном review-устройстве с настоящим прогнозом, уже сохранённым обычным приложением. Для XCTest runner заданы TEST_RUNNER_WEATHER_RUN_LIVE_REVIEW=1 и TEST_RUNNER_WEATHER_REVIEW_NETWORK_DYLIB с абсолютным путём. Без opt-in LiveReviewUITests пропускается; стандартные unit/fixture UI тесты не требуют этого harness.

При первом обычном запуске не задаются app arguments и environment. Только offline-кейс задаёт DYLD_INSERT_LIBRARIES для конкретного процесса. После terminate следующий запуск очищает launchEnvironment, и XCTest требует новое успешное сетевое обновление. Интерфейсы, proxy, VPN и сеть других приложений Mac не меняются. Профиль не устанавливается постоянно в систему.
