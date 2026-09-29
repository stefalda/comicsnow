# AGENTS.md — ComicsNow

Contesto operativo del progetto, per riprendere il lavoro in una nuova sessione.

## Cos'è

**ComicsNow** è un lettore di fumetti Flutter con rilevamento automatico delle
vignette e lettura **vignetta-per-vignetta**. Dominio volutamente semplice:
niente Riverpod / Freezed / DI container — la dependency graph è esplicita in
`lib/app_services.dart`.

- Package Dart: `comicsnow` (il nome del package **non** va cambiato).
- Nome visibile dell'app: **ComicsNow**.
- Piattaforme target: macOS (sviluppo), Android/iOS, Windows/Linux.

## Pipeline

```
CBZ ──▶ CbzReader ──▶ Comic ──▶ PageRepository ──▶ PanelReader ──▶ UI
                                    │
                                    ▼
                           PanelAnalysisService
                              │            │
                         PanelCache    PanelDetector
                              │            │
                              │            ▼
                              │      PanelDetection[]
                              │            │
                              │      PanelOrdering
                              │            │
                              │       ComicPanel[]
                              └────────────┘
```

Regole di dipendenza:

- `reader/` non conosce ONNX; parla solo con il dominio.
- `detection/` dipende da `domain/` (+ `persistence/` per la cache).
- `persistence/` non espone Drift all'esterno: solo `PanelCache`.
- Il modello produce `PanelDetection` (output del modello); il dominio usa
  `ComicPanel` (stato dell'app, con ordine di lettura e modifiche manuali).

## Layout

```
lib/
├── main.dart
├── app_services.dart            # composition root + scelta del detector
├── domain/                      # entità + interfacce, no Flutter/IO
│   ├── comic.dart
│   ├── comic_page.dart          # imagePath, NON bytes (lazy loading)
│   ├── comic_panel.dart         # bounds: Rect
│   ├── panel_detection.dart
│   ├── panel_detector.dart
│   └── page_image_source.dart
├── detection/
│   ├── onnx_panel_detector.dart # ★ ML (ONNX Runtime)
│   ├── yolo_postprocess.dart    # ★ letterbox + parsing output + NMS
│   ├── gutter_panel_detector.dart # fallback senza modello (iOS incluso)
│   ├── panel_cutter.dart        # XY-cut ricorsivo sui gutter
│   ├── otsu_threshold.dart      # soglia adattiva
│   ├── panel_ordering.dart
│   ├── panel_analysis_service.dart
│   └── panel_analysis_queue.dart # prefetch con priorità
├── persistence/                 # Drift
│   ├── database.dart            # v2: panel detections + recent comics
│   ├── panel_cache.dart
│   ├── recent_comics_store.dart # libreria
│   └── tables/
├── comic/                       # archivi (CBZ/CBR), repository, image loader
│   ├── comic_archive_reader.dart # ZIP + RAR, magic number, manifest
│   ├── app_storage.dart         # ★ dove vivono i dati dell'app (desktop/mobile)
│   ├── cover_cache.dart         # copertine per la libreria
│   ├── page_repository.dart
│   ├── image_loader.dart
│   └── natural_order.dart
├── reader/                      # PanelReader (puro) + viewport + pagina
│   ├── panel_reader.dart        # ★ macchina a stati delle 3 modalità
│   ├── panel_reader_page.dart   # UI: slider, anteprima overlay, tastiera, comfort
│   ├── camera_path.dart         # ★ interpolazione camera (zoom logaritmico)
│   ├── reader_preferences.dart  # transizione / durata / zoom massimo
│   ├── panel_viewport.dart      # ★ transizioni (zoom/dissolvenza/nessuna)
│   ├── magnifier_lens.dart      # ★ lente di ingrandimento (long press)
│   ├── image_readiness.dart     # attesa del primo frame dell'immagine
│   ├── page_loading_indicator.dart # ★ indicatore di attesa del reader
│   └── page_viewport.dart
├── settings/                    # preferenze (shared_preferences)
│   └── reader_settings.dart     # modalità + posizione di lettura per file
├── platform/
│   └── open_with.dart           # ★ "Apri con": file consegnati dal sistema
└── home/library_page.dart

tool/
└── generate_icon.dart           # sorgente icona quadrata opaca 1024x1024

assets/
├── icon/icon.png                # icona originale (sorgente)
└── models/panel_detector.onnx   # modello Inkwell

third_party/
└── flutter_onnxruntime/         # 1.8.5 senza Package.swift iOS (vedi VENDORED.md)
```

## Modalità di lettura

`ReaderMode` (`lib/reader/panel_reader.dart`):

| Modalità | Comportamento |
|---|---|
| `page` | Pagina intera, si naviga pagina per pagina |
| `panel` | Vignetta per vignetta, attraversa le pagine |
| `pageAndPanels` | Al cambio pagina mostra prima la **pagina intera**, poi al passo successivo entra nella **navigazione a vignette** di quella pagina; finita la pagina, la successiva riparte dall'intero |

Vincoli di `pageAndPanels`:

- dall'overview si avanza solo se la pagina è già stata analizzata
  (`panels.isNotEmpty`), altrimenti si resta sull'intero mentre l'analisi gira;
- **una pagina con una sola vignetta viene saltata**: l'overview mostra già
  tutta la pagina, quindi avanzare va direttamente alla pagina successiva
  (altrimenti si vedrebbe due volte la stessa immagine);
- anche tornando indietro il cambio pagina mostra l'intero;
- toccare una vignetta nell'overview entra direttamente su quella vignetta,
  restando nella stessa modalità. Sulle pagine con una sola vignetta il tocco
  naviga invece di "entrare" nella vignetta.

Tutta la logica dei tre modi vive in `PanelReader` (puro, testato in
`test/panel_reader_test.dart`); la UI legge solo `reader.showsWholePage` e
`reader.overview`.

**Default: `ReaderMode.pageAndPanels`**, e la scelta è **persistita** fra le
sessioni (vedi Preferenze).

## Formati e archivi

| Formato | Libreria | Note |
|---|---|---|
| CBZ / ZIP | `archive` (`ZipDecoder` in streaming) | estrae solo le immagini |
| CBR / RAR | plugin `rar` (UnrarKit su Apple, JUnRar su Android, WASM su web) | estrae tutto in temp, poi scansiona ricorsivamente |

`ComicArchiveReader` (`lib/comic/comic_archive_reader.dart`):

- rileva il formato dal **magic number** (`PK` vs `Rar!`), non dall'estensione,
  perché gli archivi mal etichettati sono comuni; l'estensione è solo il
  fallback;
- estrae in `getTemporaryDirectory()/comicsnow/<id>/`; le pagine sono
  riferite da `ComicPage.imagePath` (mai tutto in memoria);
- ordina naturalmente per path relativo, anche dentro sottocartelle;
- l'estrazione RAR è dietro l'interfaccia `ArchiveExtractor`, così il percorso
  RAR è testabile senza il plugin nativo (che non gira in `flutter test`).

### Costo del caricamento (misurato, 223 MB / 150 pagine)

| Fase | Tempo |
|---|---|
| Lettura indice archivio | 39 ms |
| Decompressione di tutte le pagine | **670 ms** |
| Decodifica **completa** di ogni pagina solo per width/height | **41.699 ms** ❌ |
| Solo header, `decoder.startDecode()` → `DecodeInfo` | **2.263 ms** ✅ |

Conclusioni:

- il collo di bottiglia **non** era l'estrazione: era `image.decodeImage()` su
  ogni pagina per leggerne la dimensione. Ora si usa `findDecoderForData(...)
  ?.startDecode(...)` (fallback al decode completo solo se l'header non si
  legge);
- **l'estrazione lazy non serve**: estrarre tutto costa < 1 s. Introdurla
  avrebbe richiesto di cambiare il dominio (dimensioni note solo dopo
  l'estrazione) per un guadagno trascurabile;
- durante l'estrazione il codice **cede il turno** all'event loop ogni 8 pagine
  (`_breathe`), così la UI mostra il progresso e resta reattiva.

### Riapertura istantanea (manifest)

Accanto alle pagine viene scritto `.manifest.json` con la firma dell'archivio e
le dimensioni di ogni pagina. Alla riapertura, se la firma coincide, le pagine
non vengono né estratte né rilette: **29,4 s → 0,65 s** sullo stesso CBZ
(emulatore Android).

### Identità del comic (invariante importante)

`Comic.id` **non** deriva dal percorso del file: deriva da `basename` +
**firma del contenuto** (dimensione + hash dei primi/ultimi 64 KB).

Motivo: `file_picker` copia l'archivio in una **cartella temporanea diversa a
ogni apertura** (`cache/file_picker/<timestamp>/comic.cbz`). Con un id basato
sul percorso, ogni apertura sembrerebbe un comic diverso e si perderebbero sia
la cache di estrazione sia la **posizione di lettura**
(`reading_position_<id>`). Se si cambia questo, cambiare anche i test
"the same content in another path reuses the extraction".

Le estrazioni non toccate da 30 giorni vengono eliminate al primo
caricamento (`_cleanUpStaleExtractions`), per non lasciare cartelle orfane in
temp.

### Rischio noto: il plugin `rar` non supporta Swift Package Manager

Flutter lo integra via **CocoaPods** (genera `macos/Podfile`, già presente).
Oggi funziona, ma Flutter avverte che in futuro i plugin senza SPM daranno
errore. Se succede, le alternative sono: sostituire il plugin, oppure scrivere
un'estrazione RAR nativa con SPM (o passare a un formato non proprietario).

## Preferenze

`ReaderSettings` (`lib/settings/reader_settings.dart`) usa
`shared_preferences` e persiste:

| Chiave | Contenuto | Default |
|---|---|---|
| `reader_mode` | modalità di lettura | `ReaderMode.pageAndPanels` |
| `reading_position_<comicId>` | ultima pagina letta di quel file | nessuna (parte da 0) |

Un valore sconosciuto o assente ricade sul default.

Flusso:

1. `AppServices.create()` carica le preferenze.
2. `LibraryPage` legge `settings.readMode()` e `settings.readPage(comic.id)`, li
   passa a `PanelReaderPage` come `initialMode` / `initialPageIndex`.
3. Ogni cambio modalità invoca `onModeChanged` → `settings.writeMode`.
4. Ogni cambio pagina invoca `onPageChanged` → `settings.writePage`.

Nota: `comicId` deriva dal percorso del file (`ComicArchiveReader`), quindi è
stabile fra sessioni e indipendente dal formato (CBZ o CBR).

## Barra inferiore

`PanelReaderPage` mostra sotto la pagina:

- una riga di stato con posizione, modalità corrente, frecce e un pulsante che
  apre/chiude lo **slider delle pagine** (nascosto di default, `_showScrubber`);
- quando lo slider è aperto, durante il trascinamento (`_scrubPage`) compare
  una **anteprima grande** della pagina target, decodificata ridotta
  (`ResizeImage(width: 720)`) e disegnata come **overlay in uno `Stack` sopra la
  pagina**: il layout sotto non viene ridimensionato;
- al rilascio (`onChangeEnd`) si chiama `PanelReader.goToPage`;
- `_reportPosition()` scrive la posizione solo quando la pagina cambia davvero,
  per non generare scritture inutili.

## Tastiera (desktop)

`CallbackShortcuts` + `Focus(autofocus: true)` mappano le frecce sulla stessa
navigazione dei pulsanti: `→`/`↓`/`PagGiù` avanti, `←`/`↑`/`PagSu` indietro.
Lo slider è avvolto in `Focus(descendantsAreFocusable: false)` per non rubare
le frecce alla navigazione.

## Comfort / animazione (anti-nausea)

Il problema: zoom + pan simultanei, ampiezza grande (fino a 6×), onset brusco
(`easeOutCubic`), nessun riferimento statico e centro di zoom che si sposta
quando si interpolano le `Matrix4` grezze.

Soluzioni implementate:

- **`CameraView`** (`lib/reader/camera_path.dart`, puro e testato): rappresenta
  la camera come *(punto focale in coordinate contenuto, zoom)*.
  `CameraView.lerp` interpola il focale **linearmente** e lo zoom in **scala
  logaritmica**, quindi la velocità di zoom percepita è costante e il centro
  non deriva. `PanelViewport` converte matrice → camera → matrice
  (`getMaxScaleOnAxis` + `storage[12]/[13]`, niente `MatrixUtils`).
- **`PanelTransition`** (`lib/reader/reader_preferences.dart`): `zoom` (default),
  `fade` (sfuma su nero, salta a metà animazione, torna), `none` (taglio netto).
- **`ReaderPreferences`**: `transition`, `animationDuration` (default 200 ms),
  `maxZoom` (default 3.5×, era 6×).
- **Frame statico**: `PanelViewport.frameInset` (default 10 px) tiene un bordo
  fisso attorno al contenuto che anima; i bordi dello schermo non si muovono →
  meno flusso ottico periferico.
- **`Curves.easeInOutCubic`** invece di `easeOutCubic`.
- **`MediaQuery.disableAnimationsOf(context)`** letto in
  `didChangeDependencies`: se il sistema ha "Riduci movimento", salta
  l'animazione a prescindere dalla preferenza.
- UI: bottom sheet `_PreferencesSheet` aperta dall'icona `tune`; anteprima live
  (`onPreview`), persistenza alla chiusura.

Chiavi in `ReaderSettings`: `panel_transition`, `animation_duration_ms`,
`max_zoom` (lettura difensiva: tipo inatteso → default).

## Icona dell'app

`assets/icon/icon.png` è un quadrato con angoli arrotondati trasparenti, non
esattamente quadrato (610×588). `tool/generate_icon.dart` produce la sorgente
quadrata 1024×1024 **opaca** richiesta da iOS, campionando i bordi per riempire
gli angoli; `flutter_launcher_icons` (config in `pubspec.yaml`) genera poi le
icone per Android, iOS, macOS, Windows e web.

## Scelta del detector

`AppServices._createDetector()` sceglie in quest'ordine:

| # | Condizione | Detector |
|---|---|---|
| 1 | esiste `assets/models/panel_detector.onnx` | `OnnxPanelDetector` (desktop+mobile) |
| 2 | altrimenti | `GutterPanelDetector` (senza modello) |
| 3 | altrimenti | `GutterPanelDetector` (senza modello) |

All'avvio viene loggato: `ComicsNow: detector = ... (modelVersion: ...)`, e la
schermata iniziale mostra "Motore: ...".

Cambiando `modelVersion` la chiave di cache cambia e le detection vecchie non
vengono riusate.

## Modello attualmente in uso

**Inkwell Panel Detector** — <https://huggingface.co/cedarrapidsboy/inkwell-panel-models>

- File: `assets/models/panel_detector.onnx` (= `best.onnx`, 12.256.396 byte,
  sha256 `f240e1296efd048126b26ea4ffeddc97d7c3aa667a37e3127c2afc6d5e9b9578`).
- YOLOv8-nano, **1 classe** (`panel`), input **640×640**.
- Output `[1, 5, N]` (features-first: `cx, cy, w, h, conf` in pixel 0..640).
- Training: ~3.800 pagine annotate (superhero, manga-influenced, indie, all-ages).
- Confidenza consigliata: **0.35** (0.25 sovra-rileva, 0.50 non migliora).
- **Licenza: AGPL-3.0** (derivato da Ultralytics YOLOv8). Rilevante per un
  prodotto proprietario. Il modello di reading order nello stesso repo è MIT.

Configurazione in `lib/app_services.dart`: `kOnnxModelPath`,
`kOnnxModelVersion`, `confidenceThreshold: 0.35`. Se il modello cambia formato,
`OnnxPanelDetector` espone: `hasObjectness` (YOLOv5), `isEndToEnd` (NMS inclusa),
`inputWidth`/`inputHeight`, `classNames`/`targetClasses`, `boxesAreNormalized`.

## Alternative valutate (non ancora provate)

Ordine di interesse decrescente. Vanno testate sui sample in `samples/` prima di
adottarle.

| Modello | Backbone | Dataset | Mobile | ONNX | Licenza | Note |
|---|---|---|---|---|---|---|
| **Inkwell Panel Detector** | YOLOv8n | ~3.8k comic pages | ⭐⭐⭐⭐⭐ | sì (`best.onnx`) | AGPL-3.0 | **in uso** |
| **Comic-Translate / balloon-dataset** | YOLOv8 | 8k mixed (manga, webtoon, manhua, **western**) | ⭐⭐⭐⭐ | da esportare | vedi repo | multi-dominio, interessante |
| **Poneglyph ReaderNet** | YOLO11n-seg | comics/manga | ⭐⭐⭐⭐ | sì (`panel_detector.onnx`, `ordering.onnx`, `bubble_detector.onnx`) | AGPL-3.0 | **segmentation**: input 1504×1504, dà poligoni + ordering |
| **MosesB best-comic-panel-detection** | YOLOv12x | custom comic pages | ⭐⭐ | esportabile | da verificare | mAP50 0.991 (sul proprio val set), enorme |
| **Manga YOLO26n ONNX** | YOLO26n | Manga109-s | ⭐⭐⭐⭐⭐ | sì | vedi card | 1024×1024, 10.1 MB, classi panel+text; training manga |

Link:

- <https://huggingface.co/cedarrapidsboy/inkwell-panel-models>
- <https://github.com/xulihang/balloon-dataset>
- <https://huggingface.co/Remidesbois/Poneglyph-ReaderNet>
- <https://huggingface.co/mosesb/best-comic-panel-detection>
- <https://huggingface.co/mednasserallah/manga-panel-detector-yolo26n-onnx>

### Idee emerse dalla ricognizione

1. **Reading order con modello** — Inkwell include `panel-order-model.onnx`
   (GradientBoosting, **MIT**): dato l'insieme di box, predice l'ordine.
   96.76% di accuratezza page-level. Potrebbe sostituire/migliorare
   `PanelOrdering` (che oggi è euristico riga-per-riga).
2. **Supporto poligoni** — modelli seg (Poneglyph, YOLO11n-seg) restituiscono
   maschere/poligoni, più precisi su vignette diagonali/irregolari. Estensione
   futura: `ComicPanel` con `List<Offset>? polygon` oltre a `Rect bounds`.
   Non ancora implementato.
3. **Benchmark** — prima di cambiare modello, confrontare su 50–100 pagine
   rappresentative (Bonelli, Marvel/DC, franco-belga, manga, graphic novel)
   misurando **panel recall** (una vignetta mancata = salto di contenuto),
   false panel, IoU, tempo/pagina, RAM, dimensione modello.
4. **Distillazione** — usare un modello grande offline per generare annotazioni
   e fare fine-tuning di un modello nano specifico per il corpus target.

## Licenze — attenzione

- I **pesi** del detector (Inkwell): **AGPL-3.0** (derivati da Ultralytics YOLOv8).
- ONNX Runtime (`flutter_onnxruntime`) e il codice dell'app: licenze permissive.
- Inkwell panel detector (pesi): **AGPL-3.0**.
- ONNX Runtime (`flutter_onnxruntime`): MIT/Apache (runtime, non i pesi).
- Il reading-order model di Inkwell: **MIT**.

Da risolvere prima di un prodotto proprietario/commerciale.

## Test e comandi

```bash
flutter pub get
dart run build_runner build            # genera lib/persistence/database.g.dart

flutter analyze                        # deve essere pulito
flutter test                           # 99 test + harness sample (non gating)

# Smoke test del percorso nativo ONNX (modello sintetico, 472 byte)
flutter test integration_test/onnx_panel_detector_test.dart -d macos

# Verifica che AppServices selezioni davvero il detector ONNX
flutter test integration_test/detector_selection_test.dart -d macos

# Estrazione RAR nativa reale (plugin)
flutter test integration_test/rar_extraction_test.dart -d macos \
  --dart-define=RAR_FIXTURE=$PWD/test/fixtures/sample.rar

# Valutazione del modello reale sui sample, con sweep di soglie
flutter test integration_test/onnx_samples_test.dart -d macos \
  --dart-define=SAMPLES_DIR=$PWD/samples
```

### Risultati attuali (modello Inkwell, 15 sample)

`conf 0.35` → **14/15 pagine esatte**. 0.25 → 12/15 (sovra-rileva su 2 pagine).
Unico errore residuo: `The-Lucky-Devils-...-008` (atteso 8, rilevate 7).

Confronto con l'euristica `GutterPanelDetector`: riusciva su 5/7 sample, e
falliva proprio i layout irregolari e le pagine con gutter scuri
(`page-003` 1/5, `page-008` 4/5) che il modello invece azzecca.

### Harness sui sample

`test/detection_samples_test.dart` valuta l'euristica (gira in `flutter test`).
`integration_test/onnx_samples_test.dart` valuta il modello ONNX dentro l'app.
Il nome file deve contenere il numero atteso di vignette, es.
`page-004 - 9 panels.jpg`.

## Specificità Darwin (macOS + iOS)

### Deployment target

| Piattaforma | Minimo | Dove |
|---|---|---|
| iOS | **16.0** | `IPHONEOS_DEPLOYMENT_TARGET` in **tutte** le configurazioni del pbxproj (progetto, Runner, RunnerTests) **e** `ios/Podfile` |
| macOS | **14.0** | `MACOSX_DEPLOYMENT_TARGET` + `macos/Podfile` |

Trappola: Xcode espone il target anche a **livello di progetto**, non solo di
target. Alzando solo il target dalla UI, il valore di progetto resta indietro e
Flutter genera il package SPM con quello vecchio (è esattamente il bug che ha
ttenuto iOS a 15.0). Verificare sempre con
`grep -c "IPHONEOS_DEPLOYMENT_TARGET = 16.0;" ios/Runner.xcodeproj/project.pbxproj`
(devono essere 9).

### SPM + CocoaPods ibrido

- `rar` **non supporta SPM** → Flutter lo integra via CocoaPods su entrambe le
  piattaforme (`macos/Podfile`, `ios/Podfile`, `Pods/` gitignorati).
- Il resto dei plugin Darwin usa SPM, tranne `flutter_onnxruntime` su iOS (vedi
  sotto).
- `ios/Podfile` usa `use_frameworks! :linkage => :static`: richiesto da
  `onnxruntime-objc` (binari statici).
- Aggiornare i pod quando serve: `pod repo update` e
  `pod update onnxruntime-objc onnxruntime-c`.

### Bug SPM iOS: il package generato resta a iOS 15.0

Flutter scrive `.iOS("15.0")` in
`ios/Flutter/ephemeral/Packages/FlutterGeneratedPluginSwiftPackage/Package.swift`
e **non lo alza**, quindi Xcode rifiuta qualsiasi prodotto SPM che richieda
> 15.0:

```
Target Integrity (Xcode): The package product 'flutter-onnxruntime-product'
requires minimum platform version 16.0 for the iOS platform, but this target
supports 15.0
```

Verificato: `flutter_tools` salta `updateMinimumDeployment` quando il target
risolto non supera il proprio default (`FlutterDarwinPlatform.ios` = 15.0), e
comunque il manifest viene rigenerato durante il build (`--config-only` basta a
riprodurlo). Non è aggirabile da configurazione: va tolto il plugin SPM da iOS.

### Soluzione: `flutter_onnxruntime` vendored (solo iOS)

`third_party/flutter_onnxruntime` è una copia di 1.8.5 con **il solo
`ios/flutter_onnxruntime/Package.swift` rimosso**. Conseguenze:

- **iOS** → il plugin passa da **CocoaPods** (podspec, iOS 16.0), fuori dal
  package SPM generato;
- **macOS** → resta lo Swift Package, quindi SPM, che già funzionava (la via
  CocoaPods su macOS fallisce con `Unable to resolve module dependency:
  'OnnxRuntimeBindings'`).

`analysis_options.yaml` esclude `third_party/**` dall'analisi.

Da rivedere quando Flutter sistemerà il bump della piattaforma: allora si può
rimuovere il vendoring e tornare a `flutter_onnxruntime: ^1.8.5`.

### Altro

- `macos/Runner/DebugProfile.entitlements`: la sandbox è **disattivata
  temporaneamente** (`com.apple.security.app-sandbox` = `false`) per permettere
  all'harness di integrazione di leggere `samples/`. **Da riattivare prima di
  distribuire.** `Release.entitlements` mantiene la sandbox attiva e
  `com.apple.security.files.user-selected.read-only`.
- **`ultralytics_yolo` è stato rimosso** (2026-09-27): su iOS trascinava il
  pacchetto Swift di Ultralytics con la classe `CoreAIRequest` (**Apple Core AI,
iOS 27+**). Su iOS 26 la sua metadata Swift resta nulla e l'app **crasha
  all'avvio** (`type metadata completion function for CoreAIRequest.InputTensor`
  → `swift_getSingletonMetadata` → `objc_copyClassList` → `EXC_BAD_ACCESS 0x0`),
  anche se Core AI non viene mai usato. Non ci serviva (il modello è ONNX).
  **Non reintrodurlo senza aver verificato quel pacchetto su iOS < 27.**
- Per usare l'app dalla home su iOS serve un build **release**
  (`flutter run --release`); il debug è solo per lo sviluppo.
- Note per Android (se si attiva ONNX lì): ProGuard
  `-keep class ai.onnxruntime.** { *; }`.
- Il plugin `rar` avvisa che non supporta SPM e in futuro Flutter lo tratterà
  come errore: è un rischio noto, vedi la sezione Formati.

## Selezione del file

Si usa **`file_picker`** e non `file_selector`, per due motivi verificati:

1. `file_selector_android` restituisce il **contenuto** del file nella risposta
   Pigeon (`FileResponse.bytes`): un CBZ da 300 MB viene materializzato in
   memoria e l'app muore con `OutOfMemoryError` (~109 MB di allocazione) **prima
   ancora di aprire l'archivio**. `file_picker` copia su cache con stream
   (`FileInputStream`/`FileOutputStream`) e restituisce solo il path.
2. **Nessun filtro di tipo** (`FileType.any`): su Android `allowedExtensions`
   viene passato direttamente come MIME type (`EXTRA_MIME_TYPES`), quindi un
   filtro `cbz`/`cbr` nasconderebbe tutto. L'archivio viene validato comunque
   dal **magic number** in `ComicArchiveReader`.

## Apri con (associazione dei file)

L'app dichiara i formati che legge, così il sistema la propone per aprire un
fumetto da fuori (doppio clic, "Apri con", app File, condivisione):

| Piattaforma | Dichiarazione |
|---|---|
| Android | `AndroidManifest.xml`: filtri `VIEW` (MIME fumetto + archivi per estensione) e `SEND` |
| iOS / macOS | `Info.plist`: `UTImportedTypeDeclarations` (`com.babisoft.comicsnow.cbz` / `.cbr` / `.rar`) + `CFBundleDocumentTypes` |
| Windows / Linux | **niente nel build di Flutter**: registro/MSIX e `.desktop` + shared-mime-info, cioè roba da pacchetto d'installazione |

Su Apple le maiuscole/minuscole e il tipo di ZIP li risolve il sistema
(`UTType(filenameExtension:)`), quindi la dichiarazione ha valore anche per il
selettore file — motivo per cui in futuro si potrà filtrare su iOS/macOS senza
rompere Android.

Il file che arriva è **copiato nell'app** e poi trattato come un file appena
scelto (`OpenWith` → `LibraryPage._openIncoming` → `_load`): su Android l'URI è
leggibile solo finché dura il permesso, su iOS/macOS l'URL è *security scoped* e
smette di valere quando il delegate ritorna. La copia va in `tmp/inbox` (Apple) o
`cache/inbox` (Android), cioè dove il lettore la riconosce come propria e la
sposta in `archives/`.

Protocollo con il lato nativo (canale `comicsnow/open_with`):

1. Dart si iscrive allo stream, **poi** chiama `ready` e **poi** `takePending`
   (l'ordine conta: se un file viene spinto durante l'avvio non deve arrivare
   due volte né perdersi).
2. Il lato nativo tiene la coda finché non arriva `ready`; un file tolto dalla
   coda quando viene spinto non è più in `takePending`.

Trappole verificate sul campo (ognuna è costata un giro di debug):

- **Android, `pathPattern` non è una regex** ma un *simple glob*: solo `*`, `.`
  e `\`. Le classi di caratteri (`[cC]`) non esistono, il pattern non combacia
  **mai**, e siccome il filtro ha comunque il MIME giusto sembra funzionare
  mentre in realtà accetta qualunque file. Le varianti di maiuscola si
  enumerano.
- **Android, i path pattern sono valutati solo se il filtro dichiara un host**:
  senza `host="*"` vengono ignorati e il filtro combacia con qualsiasi
  `octet-stream`. Con `host="*"` anche gli URI `file://` (authority vuota)
  funzionano.
- **macOS: AppKit non consegna `odoc` a `application(_:openFiles:)`** in questa
  app. Verificato: l'evento arriva al processo (inviato a mano con
  `NSAppleEventDescriptor`) ma il metodo del delegate non viene mai chiamato,
  mentre `applicationWillFinishLaunching` sì. Il file si prende con un handler
  AppleEvent esplicito (`NSAppleEventManager.setEventHandler` per
  `kAEOpenDocuments`) installato in `applicationWillFinishLaunching`; il metodo
  del delegate resta come fallback e il bridge ignora una seconda consegna dello
  stesso file entro 3 secondi.
- **`getTemporaryDirectory()` su Apple è `Library/Caches`**, non
  `NSTemporaryDirectory()` (path_provider_foundation 2.6 usa
  `NSCachesDirectory`). L'inbox nativa stava in `tmp/`, quindi il lettore la
  classificava come "file dell'utente" e non spostava l'archivio nella libreria:
  il fumetto si apriva ma non era più riapribile dopo lo svuotamento della
  cache. Ora `_persistArchive` riconosce anche i file nella propria `inbox`.
- **I path vanno confrontati risolti**: su macOS la stessa cartella è `/var/...`
  per un'API e `/private/var/...` per un'altra, quindi `p.isWithin` da solo
  risponde di no.
- **I dati dell'app su desktop stanno in `Application Support`**
  (`comic/app_storage.dart`): `~/Documents` è la cartella dell'utente ed è
  protetta da TCC, dove una scrittura in background fallisce in silenzio
  (succedeva alle copertine e alla copia dell'archivio). Su macOS
  `getApplicationSupportDirectory()` aggiunge già il bundle id, quindi il
  percorso è `~/Library/Application Support/com.babisoft.comicsnow.comicsnow/comicsnow/`.

Verifica:

```bash
# macOS: apre il file come farebbe il Finder
open -a build/macos/Build/Products/Debug/ComicsNow.app /tmp/test.cbz
# Android: come un file manager (content:// con grant) o da adb
adb shell am start -a android.intent.action.VIEW -t application/vnd.comicbook+zip \
  -d file:///data/local/tmp/test.cbz

# Quali filtri combaciano (senza installare nulla)
adb shell pm query-activities --brief -a android.intent.action.VIEW \
  -t application/octet-stream -d "content://com.example/Download/test.cbz"
```

Il giro completo su Android si fa dall'app **File**: Download → tocca il `.cbz` →
si apre ComicsNow (con `content://com.android.providers.downloads.documents/...`
e il grant di DocumentsUI). L'`am start` da adb con un `content://` non basta:
la shell non può concedere il permesso di lettura, e l'app riceve
`SecurityException`.

## Specificità Android

- **ONNX Runtime funziona** su Android. Verificato su emulatore arm64: logcat
  mostra `detector = OnnxPanelDetector` e la UI "Motore: ONNX (modello ML)".
  Il modello è **bundled negli asset**, non viene mai scaricato.
- `android/app/proguard-rules.pro` contiene `-keep class ai.onnxruntime.** { *; }`
  ed è collegato a `buildTypes.release` in `android/app/build.gradle.kts`.
  **Senza quella regola il release compila ma crasha** al primo caricamento del
  modello (ONNX viene caricato via reflection/JNI).
- `minSdk` = 24 (default Flutter); il plugin ONNX ne richiede 21.
- APK universale ≈ 135 MB (`libonnxruntime.so` ~19 MB per ABI + modello 12 MB):
  per distribuire usare `--split-per-abi` (≈ 50 MB per ABI).
- Avvio: `main()` non blocca il primo frame — i servizi nascono in un
  `FutureBuilder` con un loading visibile. Misurato su emulatore: `Displayed` di
  Android ~15 s, ma è avvio di processo + engine (~7 s) e GPU software; il primo
  frame Dart è a **~1.1 s** e i servizi a **~1.4 s**. Su emulatore il debug
  impiega il doppio: per l'uso reale serve una build **release**.
- `flutter build apk` avvisa che `flutter_onnxruntime` e `rar` applicano il
  Kotlin Gradle Plugin: in futuro Flutter lo tratterà come errore (stesso tipo di
  rischio di `rar` senza SPM su iOS).

## Libreria (schermata iniziale)

`LibraryPage` mostra una griglia degli ultimi fumetti aperti:

| Pezzo | Dove |
|---|---|
| Entrata della libreria | tabella Drift `RecentComics` + `RecentComicsStore` |
| Copertina | `CoverCache` (prima pagina ridotta a 400 px, in documents) |
| Avanzamento | `ReaderSettings.readPage(id)` — la stessa posizione di lettura |
| Riapertura | `ComicArchiveReader.reopen(id, archivePath)` — dal manifest, o **ri-estraendo** dall'archivio conservato |
| Rimozione | `removeComic` (pagine + archivio nostro) + `CoverCache.remove` + `clearPage` + DB |

Conseguenze da tenere presenti:

- la libreria conserva una **copia dell'archivio** in
  `documents/comicsnow/archives/<id>.<ext>`: su mobile è la copia del picker
  **spostata** (rename, stesso filesystem) invece che cancellata, quindi non
  costa spazio in più; su desktop si usa il percorso originale dell'utente;
- è quella copia che permette di **ri-estrarre senza riselezionare il file**
  quando il sistema pulisce la cache. `removeComic` cancella solo file dentro
  `archives/`: **mai** un file scelto dall'utente (c'è un test che lo verifica);
- la copia è legata all'id del comic, quindi un archivio modificato crea una
  nuova voce e lascia la vecchia (che l'utente può rimuovere);
- se il sistema pulisce la temp, `reopen` ri-estrae; se manca anche l'archivio,
  restituisce `null` e la UI lo dice;
- l'ordine `lastOpenedAt` di Drift ha risoluzione al **secondo**: c'è un
  ordinamento secondario per id per renderlo deterministico;
- `RecentComicsStore.touch` non sovrascrive con `null` la copertina e non azzera
  il conteggio pagine, così un'apertura “povera” non cancella i dati buoni.

## Lente di ingrandimento

Long press + trascinamento sulla pagina apre una lente che ingrandisce il punto
sotto il dito (`MagnifierLens`, in cima allo `Stack` del reader).

- `RawMagnifier` ingrandisce i layer disegnati **sotto** di lui nello stesso
  albero: niente screenshots, funziona anche in vista vignetta (dove il
  contenuto è dentro `InteractiveViewer`) e ingrandisce pure le box.
- `focalPointOffset = (0, lift)`: `RawMagnifier` mostra al proprio centro il
  contenuto a `focalPointOffset + centro`, quindi quel vettore è esattamente la
  distanza tra il centro della lente e il dito. Se si cambia il
  posizionamento, va cambiato anche lui (o la lente inquadra il punto sbagliato).
- Il long press **sospende la navigazione** per quel gesto: senza
  `_magnifierUsed` in `PanelReaderPage`, al rilascio sarebbe partito uno swipe.
- La lente è figlia dello `Stack` del reader, quindi riceve coordinate già nel
  sistema giusto; nessuna conversione da fare nei viewport.
- **`clipBehavior: Clip.antiAlias` non è un dettaglio estetico**: il default di
  `RawMagnifier` è `Clip.none`, e in quel caso l'ombra del `MagnifierDecoration`
  viene dipinta *sopra* l'immagine ingrandita. Con un'ombra nera sfocata il
  contenuto risultava visibilmente più scuro della pagina (misurato con una
  pagina grigia a tinta unita: 107 contro 158 fuori dalla lente, cioè più scuro
  anche dell'originale). Con il clip l'ombra finisce solo all'esterno e il
  contenuto torna esatto (158 e 158).

## File di modello nel repo

- `assets/models/panel_detector.onnx` — modello reale in uso (12 MB).
- `assets/models/smoke_test_panel_detector.onnx` — fixture di 472 byte, output
  costante, usata solo da `integration_test/onnx_panel_detector_test.dart`. Non
  viene mai selezionata dall'app (che cerca `panel_detector.onnx`).
- `assets/models/smoke_test_panel_detector.onnx` — fixture di test.
- Nessun file `.tflite`: `ultralytics_yolo` è stato rimosso dal progetto.

## Stato e prossimi passi

Fatto:

- Pipeline completa (CBZ/CBR → detection → cache → reader panel-by-panel).
- Detector ML su desktop (ONNX Runtime) verificato end-to-end su macOS.
- Modello Inkwell integrato: 14/15 pagine sample esatte.
- Fallback euristico (Otsu + polarità adattiva) se manca il modello.
- Tre modalità di lettura (pagina / vignette / pagina+vignette), default
  "pagina + vignette", persistite fra le sessioni; le pagine con una sola
  vignetta vengono saltate nel passo vignetta.
- Scorrimento pagine on demand con anteprima grande in overlay (senza
  ridimensionare la pagina) e navigazione da tastiera su desktop.
- Transizioni anti-nausea: camera con zoom logaritmico, frame statico, zoom
  massimo ridotto, opzioni dissolvenza/nessuna, rispetto di "Riduci movimento"
  e velocità/ampiezza regolabili e persistite.
- **Lente di ingrandimento**: long press + trascinamento per ingrandire il
  punto sotto il dito (funziona su pagina e vignetta, senza conflitti con pan,
  zoom e swipe).
- **Libreria**: griglia degli ultimi aperti con copertina, avanzamento e
  rimozione definitiva; l'archivio viene conservato in documents, così una
  riapertura ricostruisce le pagine da sola se il sistema svuota la cache.
- **"Apri con"**: i formati sono dichiarati al sistema (manifest Android,
  `Info.plist` Apple), il file consegnato viene copiato in casa e aperto come se
  fosse stato scelto dal selettore. Verificato su macOS (AppleEvent `odoc`) e su
  Android dall'app File con un URI `content://`. Su Windows/Linux la
  dichiarazione non si può fare nel build (serve il pacchetto d'installazione).
- **Niente più box prima dell'immagine**: i viewport aspettano il primo frame
  (`ImageReadinessMixin`) e la pagina corrente è precaricata. L'attesa usa
  `PageLoadingIndicator` (grande, animato, con etichetta `Pagina N`) invece del
  `CircularProgressIndicator` di default, che sul nero sembrava un puntino.
- Posizione di lettura memorizzata per file (livello pagina).
- **Caricamento pagine ottimizzato**: dimensioni lette dall'header (non più
  decodifica completa), progresso reale con UI reattiva, riapertura istantanea
  via manifest (29,4 s → 0,65 s su emulatore con un CBZ da 223 MB), pulizia
  della copia del picker e identità del comic basata sul contenuto.
- Supporto CBZ e CBR con rilevamento del formato dal magic number.
- Icona app per tutte le piattaforme e nome "ComicsNow" in tutti i bundle.
- Build verificati su macOS, iOS (device, release) e Android (emulatore,
  release + debug); deployment target iOS 16.0 / macOS 14.0 allineati in tutte le
  configurazioni.
- Nessun crash all'avvio su iOS né Android; ONNX attivo su entrambi.
- Prefetch asincrono delle pagine successive, cache Drift per `(pageId, modelVersion)`.

Prossimi passi possibili:

1. UI di correzione manuale delle vignette (`PageRepository.upsertPanel` /
   `removePanel` già pronti).
2. Provare il reading-order model di Inkwell (MIT) al posto di `PanelOrdering`.
3. Valutare Comic-Translate / Poneglyph sui sample (il secondo abilita i poligoni).
4. Benchmark strutturato su 50–100 pagine con panel recall come metrica primaria.
5. Riattivare la sandbox macOS in debug prima di distribuire.
6. Valutare la questione licenza AGPL se il prodotto diventa proprietario.
