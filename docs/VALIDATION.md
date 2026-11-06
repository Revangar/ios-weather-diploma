# Контрольное ревью — 1 ноября 2026, вечер

[Полный отчёт](final-review-20261101-v2/README.md) · [Результаты и хэши](final-review-20261101-v2/results.json) · [Новые скриншоты](final-review-20261101-v2/after/).

**Проверено:** Debug и Release для Simulator собраны; на iPhone 17 Pro и iPad Pro 13 Simulator каждый полный прогон — **28/28 PASS** (17 unit + 11 UI, без пропусков). Обычные запуски с реальной сетью покрыли onboarding, allow/deny, Москву и Берлин, прогнозы, быстрые переключения, настройки, удаление и перезапуск. Отдельно проверены процессный offline-кэш и крупный текст; исправлены прокрутка пустого экрана и мелкие сегменты настроек. Memgraph обычного запуска iPhone: 0 обнаруженных утечек в одном ограниченном снимке.

**Не проверено:** физические устройства (по требованию пользователя), iOS 17/27, ручной VoiceOver, длительный нагрузочный и energy-профиль, доставка напоминания, Release UI. Ранее отмеченный постоянный синий экран на физическом iPad устойчиво не воспроизведён и его причина не установлена. 25 дней, виджет, Луна, качество воздуха и линейный график не реализованы. Предварительные неудачные прогоны, определения обычного и тестового режимов и точные границы проверки сохранены в отчёте.

---

## Предыдущие проверки 1 ноября

### Предыдущий отчёт о проверках — 1 ноября 2026

## Дополнение: запуск и заголовок погоды

[Отчёт проверки запуска на Simulator](startup-ipad-20261101/README.md). Исправлен подтверждённый конфликт начальной ширины/высоты заголовка UITableView. Постоянный пустой синий экран устойчиво не воспроизведён, его точная причина не объявляется установленной. После уточнения границ задачи финальные проверки выполняются только на Simulator; пользовательские данные и настройки подписи сохранены.

[Полный инженерный и визуальный отчёт](review-20261101/README.md) · [Сводки запусков и хэши](review-20261101/results.json) · [Новые скриншоты](review-20261101/after/).

На отдельных review-устройствах iPhone 17 Pro / iPad Pro 11 M5 с существующим iOS 26.5 выполнены обычные живые сценарии без `--ui-testing`/`--fixture-network`, системные allow/deny, Москва/Берлин, часы/дни, быстрые переключения, настройки, удаление, повторный запуск и настоящий процессный запрет сети с кэшем и восстановлением. Debug/Release собраны. Проверены 16 различных unit, 6 fixture UI и 2 ordinary integration UI на каждом устройстве; точные границы полных и повторных запусков приведены в новом отчёте. Две opt-in проверки без переменной запуска корректно SKIPPED и не засчитаны как PASS.

**Не проверено:** физические устройства, исполнение iOS 17, Release UI, ручной VoiceOver, длительный soak/energy, доставка напоминания. Animation Hitches на этом Simulator не поддержан; измерение FPS не заявляется. Три фактических `leaks` дали 0 leaks в ограниченных навигационных сессиях. Сохранённые отличия от макетов, 25 дней/виджет/Луна/воздух описаны в новом отчёте.

---

## Исторический отчёт 30 октября — не доказательство финального прогона

Ниже сохранены исходные результаты и ограничения 30 октября. При расхождении с ними актуален отчёт 1 ноября выше.

# Проверки диплома — 30 октября 2026

Каноническое рабочее дерево: `/Users/incar/Documents/Codex/2026-10-30/codex-weather-diploma-task-md-mac/outputs/ios-weather-diploma`.
Проект `WeatherDiploma.xcodeproj`, shared scheme `WeatherDiploma`, Swift 6, deployment target iOS 17.0.

## Окружение и границы

Фактически обнаружены Xcode **26.6 (17F113)**, iOS/iOS Simulator SDK **26.5**, установленный runtime **iOS 26.5 (23F77)**. Проверки выполняются на существующих iPhone 17 Pro (`EAC1FFA7-FDB5-4D63-8919-B6EEEB4C3387`) и iPad Pro 11-inch M5 (`4375A014-5745-433F-B0A0-3387DA052058`). Никаких runtimes/platform components не скачивали и не импортировали. Физические устройства не использовались.

В Downloads и каталогах Projects, Desktop, Documents/Codex не найден готовый Weather-проект/архив (проверены имена на верхних уровнях, это не полный поиск по всему диску). Создан новый проект. Репозиторий `Revangar/Navigation` не использован и не изменён. Из-за недоступного Git proxy `127.0.0.1:7890` clone/push выполнялись с разовыми `git -c http.proxy= -c https.proxy=`; глобальная конфигурация не менялась.

Прочитан полный [официальный README](https://github.com/netology-code/iosdt-diplom), просмотрены Design/1.jpg–5.jpg, addScreen.png и mapOfApp.png на commit `35509fd6994f4dd250344528ed5f5fd394a88034`. Интеграция Figma отсутствует в доступных инструментах; использован разрешённый графический fallback. Системные символы заменяют исходную иллюстрацию; пиксельное совпадение с Figma не заявляется.

## Матрица требований

| Требование | Статус | Реализация / доказательство |
|---|---|---|
| UIKit и адаптивная Auto Layout, iPhone/iPad | PASS | Реальная компиляция и запуск; портрет, landscape, максимальный accessibility-текст, тёмный iPad |
| Onboarding и системная геопозиция | PASS | UI-тесты реально нажимают разрешение и запрет в системном диалоге; координаты Simulator установлены в Москве |
| Отказ, пустое состояние и ручной ввод | PASS | «+» доступен после отказа; onboarding не повторяется после перезапуска |
| UIAlertController, геокодинг, выбор неоднозначного города | PASS | Живой API и URLProtocol-тесты; город/регион/страна в action sheet, popover anchor на iPad |
| Не найденный город, дубликаты, ошибки сети | PASS | UI и unit; геокодинг без сети требует повторить запрос после восстановления связи |
| Несколько городов и индикация | PASS | UIPageViewController, swipe между Москвой/Берлином, UIPageControl, сохранение выбранного города |
| Текущая температура, состояние, влажность, осадки, ветер | PASS | Живые ответы для двух городов и реальный главный экран |
| Местные дата/время, восход/закат, длина дня | PASS | IANA timezone, Unix timestamps, nil вместо выдуманных значений; тесты DST и смены календарной даты |
| 7 дней, кастомные прокручиваемые ячейки | PASS | DailyCell; семь фактических записей; UI доходит до последнего дня при большом тексте |
| Часы UICollectionView и экран 24 часов | PASS | 24 последовательных часа от текущего часа ответа; выбор часа, детали осадков/ветра/влажности/облачности |
| Выбор дня и дневная детализация | PASS | Горизонтальный список дней; реальные репрезентативные часы дня/ночи, солнце и УФ |
| Core Data: все отображаемые погодные данные и города | PASS | Полный Codable snapshot в SQLite; повторное открытие файла проверено; прогнозы изолированы по city.id |
| Кэш до сети, офлайн, loading/error/empty/stale | PASS | Кэш читается перед запросом; UI-перезапуск с ошибкой транспорта показывает полный сохранённый прогноз; устаревание после часа |
| Работа вне main, отмена устаревших запросов | PASS (код + UI) | URLSession async, detached JSON decode, private queue Core Data; переключение городов; отдельный stress/performance profiler не запускался |
| Сохранение настроек | PASS | °C/°F, скорость, 12/24 часа; UI-перезапуск и unit; настройка напоминаний реализована отдельно |
| 25 дней | ОГРАНИЧЕНИЕ | Проверенный обычный Open-Meteo API даёт максимум 16; показываем 7, кнопка объясняет ограничение, фальшивого прогноза нет |
| Виджет со звёздочкой | НЕ РЕАЛИЗОВАН | Дополнительный пункт, отмечен явно |
| Attribution и permissions | PASS | Open-Meteo/GeoNames в UI; HTTPS; NSLocationWhenInUseUsageDescription, reduced accuracy, PrivacyInfo; секретов нет |
| GitHub: отдельные main и feature, PR | PASS | [PR #1](https://github.com/Revangar/ios-weather-diploma/pull/1), OPEN, main ← feature/diploma-weather-app; не мержен |

## Как выполнялись проверки

Команды запускались из родительского рабочего каталога `codex-weather-diploma-task-md-mac`; логи и xcresult лежат в его `outputs/`, вне Git-репозитория. Здесь приведены реальные аргументы, а не подмена компиляции синтаксическим parse.

```sh
xcodebuild -version
xcodebuild -showsdks
xcrun simctl list runtimes
xcrun simctl list devices available
xcodebuild -list -project outputs/ios-weather-diploma/WeatherDiploma.xcodeproj

xcodebuild -project outputs/ios-weather-diploma/WeatherDiploma.xcodeproj \
  -scheme WeatherDiploma -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath work/DerivedData CODE_SIGNING_ALLOWED=NO build

xcodebuild -project outputs/ios-weather-diploma/WeatherDiploma.xcodeproj \
  -scheme WeatherDiploma -configuration Release \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath work/ReleaseDerived CODE_SIGNING_ALLOWED=NO build

xcrun simctl location EAC1FFA7-FDB5-4D63-8919-B6EEEB4C3387 set 55.75,37.62
xcodebuild -project outputs/ios-weather-diploma/WeatherDiploma.xcodeproj \
  -scheme WeatherDiploma \
  -destination 'platform=iOS Simulator,id=EAC1FFA7-FDB5-4D63-8919-B6EEEB4C3387' \
  -derivedDataPath work/DerivedData -resultBundlePath outputs/iphone-tests-final.xcresult \
  -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO test
```

Полный iPhone-прогон: **12 unit + 5 UI, 0 failures**, `iphone-tests-final.xcresult`. После ограниченных исправлений контраста и переходов из настроек основной пользовательский сценарий повторён, `iphone-management.xcresult`: **1 UI, 0 failures**. Новый тест управления городами запускался отдельно; его итог указан в итоговой сводке ниже. Первый запуск с двумя `-only-testing` обнаружил только ранее известный тест; факт PASS этого запуска не считался доказательством нового теста. Выполнена `-enumerate-tests`, затем запуск нового теста с `test-without-building`.

Для iPad использованы те же продукты `work/DerivedData`, `test-without-building`, destination `4375A014-5745-433F-B0A0-3387DA052058`, `-only-testing:WeatherDiplomaUITests/WeatherDiplomaUITests/testCitiesForecastDetailsSettingsAndOfflineRelaunch` и `-only-testing:WeatherDiplomaUITests/WeatherDiplomaUITests/testAdaptiveLandscapeAndLargeText`. Тёмная тема установлена `xcrun simctl ui ... appearance dark`. Первая проверка: **2 UI, 0 failures**, `ipad-tests.xcresult`; повтор после исправлений оформления — в итоговой сводке.

Unit-покрытие: реальный JSON/DTO и 24 часа, null и повреждённые массивы, контракт URL, Unicode/неоднозначность/пустой поиск, invalid query без запроса, HTTP 429 и offline, SQLite reopen/удаление/изоляция городов, сохранение кэша при неудачном обновлении, DST, настройки и конверсия.

UI-кейсы используют явный DEBUG-режим с отдельным SQLite/UserDefaults namespace и баннером «Тестовые данные». Источник — сохранённый реальный ответ; это воспроизводимые проверки UI, не доказательство текущей погоды в фикстурном Берлине. Офлайн-моделирование — реальная ошибка `URLError.notConnectedToInternet` на уровне URLProtocol, без отключения сети Mac. Системные диалоги геопозиции — настоящие, не заглушка.

Отдельно Swift-клиент проверен с живыми API для Москвы и Берлина: обе пары geocoding+forecast прошли, timezone Europe/Moscow и Europe/Berlin, 7 дней/168 часов/next24=24, текущая температура и длина дня присутствуют. Итог `live-api.log`. Обычный запуск приложения использует реальную сеть, без тестовых аргументов.

## Найденные и исправленные проблемы

1. Swift 6: изоляция CLLocationManagerDelegate — конформанс `@preconcurrency` при создании менеджера на MainActor.
2. Optional weather codes и range patterns — явная обработка nil до switch.
3. Реальная ошибка DTO: convertFromSnakeCase не совпадал с именами полей с цифрами. ForecastDTO переведён на явные CodingKeys; первые unit-тесты зафиксировали 6 ошибок, после исправления все 12 PASS.
4. Быстрая смена городов: идентификатор запроса не позволяет завершению отменённой Task сбросить новую.
5. Контраст настроек/ссылок тёмной темы, индикация выбранного дня, декоративная линия при accessibility-тексте и заголовок дневного списка исправлены после просмотра скриншотов.
6. Тест системного запрета искал неверную локализованную подпись. Фактическая кнопка iOS 26.5 — «Запретить»; повторный полный прогон PASS. Сбои первоначального теста не выдаются за успешные проверки.
7. Переходы из модальных настроек сохраняют callback до окончания dismiss; слабая ссылка на закрываемый controller могла потерять действие.

Xcode выводит предупреждение metadata extraction без AppIntents.framework — App Intents в проекте не используются. При `CODE_SIGNING_ALLOWED=NO` для тестов есть предупреждения о пропуске strip подписанных библиотек XCTest. В части запусков сам Xcode сообщает `DebuggerVersionStore.StoreError`, но итоговые сессии завершаются PASS. Эти предупреждения не скрываются и не трактуются как несуществующие компиляционные ошибки.

## Скриншоты и непроверенные области

[Каталог доказательств](evidence/): `iphone-*` — светлая тема, `ipad-*` — тёмная; `*-13/14/15-*` — максимальный accessibility-текст и landscape. Скриншоты экспортированы из xcresult; ключевые экраны визуально просмотрены. `iphone-live-weather.png` относится к обычному запуску с живой сетью (без fixture-баннера). Полные xcresult доступны локально в родительском outputs; в Git идут только компактная сводка и PNG.

**NOT_RUN:** физический iPhone/iPad; iOS 17 runtime (минимальная поддержка заявлена конфигурацией, исполнение проверено на iOS 26.5); Release UI-прогон; Instruments/длительное нагрузочное тестирование; реальное отключение сетевых интерфейсов Mac; фактическая доставка локального напоминания в 08:00; App Store/подпись устройства. Напоминание реализовано как локальная ежедневная заявка UNCalendarNotificationTrigger, не как push с актуальным прогнозом. VoiceOver вручную не проходили. Миграция из старой несуществующей схемы не проверялась.

25-дневный прогноз и виджет не объявляются выполненными. Луна/качество воздуха из обзорной карты не подменяются выдуманными данными. Учебное приложение готово к проверке в пределах фактически выполненных сборок и сценариев, а не к утверждению о сертифицированном продакшне.

## Итоговая сводка

| Проверка | Фактический результат | Доказательство |
|---|---|---|
| Debug generic Simulator, финальный код | PASS, BUILD SUCCEEDED | build-debug-final.log |
| Release generic Simulator, финальный код | PASS, BUILD SUCCEEDED | build-release-final.log |
| Полный iPhone-прогон | 12 unit + 5 UI, 0 failures | iphone-tests-final.xcresult, JSON summary |
| Основной iPhone-сценарий после UI-правок | 1 UI, 0 failures | iphone-management.xcresult |
| Управление городами и location из Settings | 1 UI, 0 failures | iphone-management-verified.xcresult |
| Финальный iPad dark/landscape/large text | 2 UI, 0 failures | ipad-tests-final.xcresult |
| Живые geocoding + forecast для Москвы/Берлина | PASS для двух городов | live-api.txt |
| Обычный запуск iPhone без fixture-аргументов | PASS, показан живой прогноз | iphone-live-weather.png |

Итого проверено **12 разных unit-тестов, 6 разных UI-кейсов на iPhone и 2 UI-кейса на iPad**; повторы не складываются в число уникальных тестов. Сводки xcresult: [iPhone](evidence/iphone-tests-summary.json), [управление городами](evidence/management-tests-summary.json), [iPad](evidence/ipad-tests-summary.json). [Краткие строки PASS и build](evidence/checks.txt), [хэши исходников и логов](evidence/validation-summary.json), [окружение](evidence/environment.txt).

Финальная iPhone accessibility/landscape проверка после удаления декоративной линии при крупном тексте: **1 UI, 0 failures**, `iphone-adaptive-final.xcresult`, [JSON summary](evidence/adaptive-tests-summary.json). PNG 13–15 обновлены из этой сессии.

## Публикация

Репозиторий: [Revangar/ios-weather-diploma](https://github.com/Revangar/ios-weather-diploma).
PR: [#1 — UIKit-прогноз погоды с Core Data и офлайн-режимом](https://github.com/Revangar/ios-weather-diploma/pull/1), **OPEN**, base `main`, head `feature/diploma-weather-app`. Реализация и проверенные исходники: commit `93701a97e3a95ed54ca8a05c16fbbabb0a68e005`; исходная main: `0ffb5e8`. Последующее изменение отчёта добавляет только ссылку публикации. PR не мержился. GitHub CI не настроен; приведены результаты локальных запусков.

`gh auth status`, создание отдельного репозитория, push main/feature, `gh pr create`, `gh pr status`, проверка OPEN/mergeable и `git diff --check` выполнены на Mac. В PR опубликованы критерии проверки, ограничения и скриншоты.
