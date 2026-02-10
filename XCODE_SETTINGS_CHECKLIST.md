# Xcode Settings Checklist for sherpa-onnx Integration

## Build Settings (в поиске вводить названия)

### 1. Objective-C Bridging Header
```
Typeasy/Typeasy-Bridging-Header.h
```

### 2. Header Search Paths
```
$(SRCROOT)/Typeasy/Libraries/sherpa-onnx/include    [recursive]
```

### 3. Library Search Paths
```
$(SRCROOT)/Typeasy/Libraries/sherpa-onnx
```

### 4. Other Linker Flags
```
-lc++
```

## Build Phases

### 5. Link Binary With Libraries
Должны быть добавлены:
- ✅ libsherpa-onnx.a
- ✅ HotKey (уже есть)
- ✅ WhisperKit (уже есть)

---

## Как проверить что всё работает

1. **Build проект**: Cmd+B
2. Если нет ошибок линковки - всё настроено правильно!
3. Если есть ошибки типа "symbol not found" - значит libc++ не добавлен
4. Если есть ошибки типа "header not found" - проверить Header Search Paths

---

## Troubleshooting

### Ошибка: "Bridging header not found"
**Решение**: Проверить путь к bridging header, должен быть относительно корня проекта

### Ошибка: "Undefined symbols for architecture arm64"
**Решение**: Проверить что libsherpa-onnx.a добавлен в "Link Binary With Libraries"

### Ошибка: "ld: library not found for -lc++"
**Решение**: Добавить libc++.tbd вместо -lc++ (см. альтернативный метод ниже)

---

## Альтернативный метод добавления libc++.tbd

Если `-lc++` не работает:

1. Build Phases → Link Binary With Libraries
2. Нажать "+"
3. В поиске ввести: **libc++.tbd**
4. Выбрать **libc++.tbd** из списка
5. Кликнуть "Add"
