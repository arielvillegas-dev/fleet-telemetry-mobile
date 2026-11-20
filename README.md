# Fleet Telemetry Mobile (Flutter Demo)

Aplicación móvil demostrativa en **Flutter y Dart** que ilustra patrones de ingeniería para aplicaciones de transporte, GPS y conectividad intermitente.

> **Nota:** Demostración técnica independiente creada para portafolio con datos 100 % sintéticos y sin dependencias de infraestructura ni marcas privadas.

## 1. Problema que resuelve
En aplicaciones de monitoreo de flotas y campo, la pérdida temporal de red móvil y las lecturas GPS imprecisas provocan pérdida de trazabilidad y saltos erróneos en el cálculo de distancia. Esta demo implementa un pipeline local con **filtrado de calidad de señal**, **cola persistente offline en SQLite (`sqflite`)** y **sincronización en lote idempotente**.

## 2. Tecnologías utilizadas
- **Framework / Lenguaje:** Flutter & Dart (`^3.12.2`).
- **Manejo de estado:** `provider` (`ChangeNotifier`).
- **Persistencia local:** `sqflite` + `path`.
- **Mapas y geoposicionamiento:** `flutter_map` + `latlong2` + fórmula Haversine.
- **Red:** `http` con timeouts explícitos y modo simulador offline.

## 3. Arquitectura general
- `lib/models/telemetry_point.dart`: Modelo inmutable con `clientEventId` único para evitar duplicados al reintentar envíos.
- `lib/services/gps_quality_filter.dart`: Valida límites geográficos, rechaza `(0,0)`, exige precisión mínima (`<= 50 m`) y filtra saltos de velocidad implausibles (`> 180 km/h`).
- `lib/services/offline_queue_store.dart`: Abstracción `TelemetryQueueStore` con implementación SQLite (`SqfliteTelemetryStore`) y doble en memoria (`InMemoryTelemetryStore`) para pruebas rápidas.
- `lib/services/telemetry_sync_client.dart`: Transporte REST batch (`/api/v1/trips/{tripId}/telemetry-batch`) + transporte simulado para pruebas offline sin servidor.
- `lib/providers/tracking_provider.dart`: Orquestador reactivo del estado de viaje, métricas y sincronización.
- `lib/screens/tracking_dashboard_screen.dart`: Interfaz interactiva con mapa, switch de simulación offline y acciones de prueba.

## 4. Funcionalidades implementadas
- Simulación de puntos GPS válidos y ruidosos.
- Filtrado en tiempo real con contadores de aceptados, rechazados y kilómetros acumulados.
- Cola persistente SQLite cuando la red está desconectada.
- Sincronización en lote al restablecer conectividad.

## 5. Instrucciones para ejecutarlo

```bash
flutter pub get
flutter run
```

Opcionalmente, si se conecta con el backend demostrativo `fleet-ops-platform`, copiar `.env.example` a `.env` con la URL local.

## 6. Pruebas disponibles
```bash
flutter analyze
flutter test
```
Incluye pruebas unitarias de filtro GPS (`gps_quality_filter_test.dart`), transporte HTTP mockeado (`telemetry_sync_client_test.dart`), proveedor de estado (`tracking_provider_test.dart`) y widget tests (`widget_test.dart`).

## 7. Contribución real al desarrollo
Demostración técnica diseñada por Carlos Ariel Villegas Flores replicando patrones arquitectónicos reales de telemetría móvil offline, con asistencia de herramientas de IA para acelerar la estructura base de widgets y pruebas, verificada localmente con `flutter analyze` y `flutter test`.
