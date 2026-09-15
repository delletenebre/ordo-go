# Иконки ORDO

Золотое войлочное пламя на бордовом медальоне с кремовой окантовкой.
Основной фон — `#182633`. Изображения созданы встроенным image_gen;
исходники и полные промпты находятся в [source/PROMPTS.md](source/PROMPTS.md).

## Файлы и подключение

| Назначение | Файлы |
| --- | --- |
| Основная иконка Godot | `app-icon.png`, 1024 × 1024 |
| Windows | `desktop/ordo.ico`, кадры 16–256 px |
| macOS | `desktop/ordo.icns`, кадры 16–1024 px |
| Linux / универсальные PNG | `desktop/icon-*.png`, 16–1024 px |
| Android launcher | `android/launcher-*.png`, 48/72/96/144/192 px |
| Android adaptive | `android/adaptive-*-432.png`, фон, передний и монохромный слои |
| Google Play | `android/play-store-512.png` |
| iPhone / iPad / App Store | `ios/icon-*.png` и `ios/catalog/AppIcon.appiconset/` |
| Контроллер в браузере | `web/icon-*.png`, favicon и Apple touch icon |

`project.godot` использует PNG, ICO и ICNS. Android-пресет подключает все
четыре launcher-ресурса. Добавлен iOS-пресет с путями ко всем размерам,
режимом экспорта проекта Xcode и bundle ID `kg.delletenebre.ordo`.
Для сборки и подписи iOS укажите свой Apple Team ID и provisioning profile.
Сами APK/IPA в рамках подготовки иконок не собирались.

iOS-файлы непрозрачные RGB PNG, квадратные, без заранее скруглённых углов.
Каталог `ios/catalog/AppIcon.appiconset` также можно скопировать в `Assets.xcassets` проекта Xcode.
Godot использует PNG непосредственно из `ios/`. Каталог Xcode исключён из импорта
Godot, чтобы в нём не появлялись посторонние `.import`-файлы.

В Android передний слой помещён в центральные 256 × 256 px холста 432 × 432:
основной круг укладывается в безопасную область. Монохромный слой содержит
силуэт пламени для тематических иконок. Фон полностью непрозрачный.
См. [адаптивные иконки Android](https://developer.android.com/develop/ui/compose/system/icon_design_adaptive)
и [параметры иконок Godot iOS](https://docs.godotengine.org/en/latest/classes/class_editorexportplatformios.html).

HTML контроллера подключает favicon и Apple touch icon; оба HTTP-сервера
(встроенный Godot и Node relay) отдают файлы из `web/`.

## Повторная подготовка размеров

Из корня проекта:

```sh
godot --headless --path . --script res://tools/icons/build_icons.gd
```

На macOS вместо `godot` можно использовать
`/Applications/Godot.app/Contents/MacOS/Godot`.
Команда пересоздаёт производные файлы из сохранённых исходников без сети.
Каталог `source/` исключён из импорта Godot через `.gdignore`.

## Проверено

Размеры и RGB-формат всех слотов iOS, прозрачность слоёв Android и их попадание
в безопасный круг, пути в пресетах, выдача PNG встроенным HTTP-сервером.
ICO и ICNS успешно прочитаны декодерами; каталог iOS скомпилирован `xcrun actool`
для iPhone/iPad без ошибок и предупреждений. Проверен синтаксис Node relay.
