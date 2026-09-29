# ComicsNow

Lettore di fumetti locale con rilevamento automatico delle vignette e lettura
vignetta-per-vignetta (panel-by-panel).

Questa è una **prima implementazione**, volutamente senza Riverpod / Freezed /
DI container: il dominio è piccolo e la dependency graph è esplicita in
`lib/app_services.dart`.

## Architettura

```
Comic files (CBZ)
      │
      ▼
  CbzReader ──▶ Comic ──▶ PageRepository ──▶ PanelReader ──▶ Flutter UI
                              │
                              ▼
                     PanelAnalysisService
                        │            │
                   PanelCache    PanelDetector ──▶ YOLO
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

- `reader/` non conosce ONNX.
- `detection/` dipende solo da `domain/` (+ `persistence/` per la cache).
- `persistence/` non espone Drift all'esterno: solo `PanelCache`.
- Il modello produce `PanelDetection` (output del modello), il dominio usa
  `ComicPanel` (stato dell'app, con ordine di lettura e modifiche manuali).

### Struttura

```
lib/
├── main.dart
├── app_services.dart          # composition root
├── domain/                    # entità + interfacce, zero dipendenze da Flutter
│   ├── comic.dart
│   ├── comic_page.dart
│   ├── comic_panel.dart
│   ├── panel_detection.dart
│   ├── panel_detector.dart
│   └── page_image_source.dart
├── detection/
│   ├── onnx_panel_detector.dart   # ML su desktop (ONNX Runtime)
│   ├── yolo_postprocess.dart      # letterbox + parsing + NMS
│   ├── yolo_panel_detector.dart   # ML su mobile
│   ├── gutter_panel_detector.dart # senza modello (fallback)
│   ├── panel_cutter.dart          # XY-cut ricorsivo sui gutter
│   ├── panel_ordering.dart
│   ├── panel_analysis_service.dart
│   └── panel_analysis_queue.dart
├── persistence/
│   ├── database.dart          # Drift
│   ├── panel_cache.dart
│   └── tables/panel_detections.dart
├── comic/
│   ├── cbz_reader.dart
│   ├── page_repository.dart
│   ├── image_loader.dart
│   └── natural_order.dart
├── reader/
│   ├── panel_reader.dart      # controller puro, niente Flutter
│   ├── panel_reader_page.dart
│   ├── panel_viewport.dart
│   └── page_viewport.dart
└── home/
    └── library_page.dart
```

## Setup

```bash
flutter pub get
dart run build_runner build          # genera lib/persistence/database.g.dart
flutter test
flutter run
```

Requisiti macOS: **macOS 14+** (per ONNX Runtime), Swift Package Manager
attivo **e CocoaPods** (il plugin `rar` per i CBR non supporta SPM). In
`macos/Runner/DebugProfile.entitlements` la sandbox è temporaneamente
disattivata per far leggere i sample all'harness di integrazione: **va
riattivata prima di distribuire** (vedi [AGENTS.md](AGENTS.md)).

## Modalità di lettura

Dal menu in alto a destra si sceglie fra tre modalità:

| Modalità | Comportamento |
|---|---|
| **Pagina** | Pagina intera, si naviga pagina per pagina |
| **Vignette** | Vignetta per vignetta (attraversa le pagine) |
| **Pagina + vignette** | Al cambio pagina mostra prima la pagina intera; al passo successivo si entra nella navigazione a vignette di quella pagina. Finita la pagina, la successiva riparte dall'intero. Se la pagina ha **una sola vignetta** il passo "vignetta" viene **saltato** (l'intero è già la vignetta), evitando di vedere due volte la stessa immagine |

In "Pagina + vignette" la barra in basso mostra `Pagina intera · avanza per le
vignette`: tocca a destra, swipe, o la freccia per entrare nelle vignette.
Toccando direttamente una vignetta dall'anteprima si salta subito a quella
(non possibile sulle pagine con una sola vignetta: lì il tocco naviga).

La logica dei tre modi è in `PanelReader` (puro e testato), non nella UI.
Il default è **Pagina + vignette** e la scelta viene **persistita** fra le
sessioni (`shared_preferences`).

### Barra inferiore e scorrimento pagine

Lo **slider delle pagine è nascosto di default** e si apre a richiesta con
l'icona di espansione nella barra in basso (si chiude con la stessa icona).

Mentre trascini lo slider, una **anteprima grande** della pagina di
destinazione appare **sopra la pagina**, come overlay in un layer separato: la
pagina sottostante **non viene ridimensionata né spostata**. Al rilascio si
salta a quella pagina (`goToPage`), che in "Pagina + vignette" riparte
dall'intero.

### Lente di ingrandimento

**Tieni premuto** su una pagina o su una vignetta: compare una lente (280 px,
2,5×) che ingrandisce il punto sotto il dito. Spostando il dito la lente lo
segue, e si chiude al rilascio. Funziona sia in vista pagina sia in vista
vignetta, e ingrandisce anche le box dei pannelli (utile per controllare il
rilevamento).

Dettagli:

- è `RawMagnifier` (lo stesso widget del magnifier nativo dei campi di testo),
  posizionato in cima allo `Stack` del reader; quindi ingrandisce ciò che è
disegnato sotto di lui, senza screenshots né copie dell'immagine;
- la lente sta **sopra** il dito e viene tenuta dentro lo schermo; se sopra non
  c'è spazio si **ribalta sotto**. Il distacco dal dito è **derivato dalla
dimensione** (metà lente + 16 px): così una lente grande non finisce sotto il
dito, e il margine libero resta lo stesso (140 o 280 px non cambia);
- l'ombra è disegnata **solo all'esterno** (`clipBehavior: Clip.antiAlias`):
  `RawMagnifier` di default la dipinge anche *sopra* il contenuto ingrandito,
  che quindi usciva più scuro della pagina (misurato su una pagina grigia:
  107 invece di 158 fuori dalla lente; ora 158 e 158);
- lungo i bordi e negli angoli l'offset focale viene **rimesso al volo**
  (`magnifierPlacement`): `RawMagnifier` mostra al centro il contenuto a
  `focalPointOffset + centro`, quindi quando la lente viene spostata per restare
  a schermo l'offset deve seguirla, altrimenti ingrandirebbe un punto diverso da
  quello sotto il dito;
- un long press **non** viene interpretato come swipe: la navigazione è
  sospesa per quel gesto (`_magnifierUsed`);
- nessun conflitto con pan/zoom: se muovi subito il dito vince
  `InteractiveViewer` (pan), se lo tieni fermo mezzo secondo vince la lente.

### Tastiera (desktop)

Le frecce si comportano come i pulsanti in basso a destra:

| Tasto | Azione |
|---|---|
| `→`, `↓`, `PagGiù` | avanti |
| `←`, `↑`, `PagSu` | indietro |

Lo slider non prende il focus da tastiera, così le frecce restano dedicate
alla navigazione.

### Comfort di lettura

L'animazione tra vignette è pensata per **non dare nausea**, senza rinunciare
allo zoom. Dal menu `tune` in alto si aprono le opzioni:

| Opzione | Valori | Default |
|---|---|---|
| Transizione | Zoom / Dissolvenza / Nessuna | Zoom |
| Velocità animazione | 80–400 ms | 200 ms |
| Zoom massimo | 2–6× | 3.5× |

Perché è più comodo (e cosa è cambiato):

- **camera coerente** invece di interpolare le matrici: il punto focale è
  interpolato linearmente e lo **zoom in scala logaritmica**, quindi la velocità
  di zoom percepita è costante e il centro dell'ingrandimento non "deriva"
  (`lib/reader/camera_path.dart`);
- **curva morbida** `easeInOutCubic` invece di `easeOutCubic`: l'animazione
  parte e finisce a velocità zero, senza lo scatto iniziale;
- **frame statico**: il contenuto anima dentro un bordo fisso (`frameInset`),
  quindi i bordi dello schermo non si muovono e il flusso ottico periferico —
  la causa principale del malessere — è ridotto;
- **ampiezza ridotta**: zoom massimo 3.5× (era 6×);
- **"Riduci movimento"** di sistema (`MediaQuery.disableAnimationsOf`) ha la
  precedenza: l'animazione viene disattivata a prescindere;
- **Dissolvenza** = lo schermo sfuma su nero, salta di posizione, e torna: zero
  auto-movimento. **Nessuna** = taglio netto.

### Ripresa della lettura

La **posizione di lettura è memorizzata per file** (livello pagina, non
vignetta), con chiave `reading_position_<comicId>` dove `comicId` deriva dal
percorso del file. Riaprendo lo stesso file si riparte dalla pagina dove si
era rimasti.

## Formati supportati

| Formato | Note |
|---|---|
| **CBZ / ZIP** | estrazione in streaming delle sole immagini |
| **CBR / RAR** | estrazione via plugin `rar` (UnrarKit su macOS/iOS, JUnRar su Android) |

Il formato è rilevato dal **contenuto** (magic number), non dall'estensione:
anche un `.cbr` che è in realtà uno ZIP (o viceversa) viene letto
correttamente.

La selezione del file usa `file_picker` **senza filtro di tipo**. Ora che i
tipi `cbz`/`cbr` sono dichiarati (vedi sotto) il filtro funzionerebbe su
iOS/macOS, dove il plugin risolve l'estensione in un UTI; su Android però
`allowedExtensions` viene passato come MIME type e nasconderebbe tutto. Senza
filtro si possono anche scegliere file con estensione sbagliata, che il lettore
riconosce comunque dal contenuto.

### Apri con (associazione dei formati)

L'app **dichiara i formati che sa leggere**, così il sistema può proporla per
aprire un fumetto da fuori — doppio clic, "Apri con", app File, condivisione:

| Piattaforma | Dove si dichiara | Cosa si ottiene |
|---|---|---|
| **Android** | `AndroidManifest.xml`: filtri `VIEW` e `SEND` | compare in "Apri con" e nella condivisione, per i MIME fumetto e per gli archivi riconosciuti dall'estensione |
| **iOS** | `Info.plist`: `UTImportedTypeDeclarations` + `CFBundleDocumentTypes` | compare in "Apri con" e in File; `cbz`/`cbr` diventano tipi noti al sistema |
| **macOS** | come iOS | associazione dei file, doppio clic, trascinamento sull'icona |
| **Windows / Linux** | **non si dichiara nel build**: registro/MSIX su Windows, `.desktop` + shared-mime-info su Linux — roba da pacchetto d'installazione | — |

I tipi dichiarati sono `com.babisoft.comicsnow.cbz`, `.cbr` e `.rar` (per gli ZIP
si usa il tipo di sistema `public.zip-archive`). Su Android si dichiarano i MIME
standard dei fumetti (`application/vnd.comicbook+zip`, `…-rar`,
`application/x-cbz`, `application/x-cbr`) e, per i file manager che riportano
`application/octet-stream`, anche l'estensione nel percorso.

Quando il sistema consegna un file, l'app ne fa una **copia propria** e poi lo
tratta come un file appena scelto: su Android l'URI è leggibile solo finché dura
il permesso, su iOS/macOS l'URL è *security scoped* e smette di valere appena il
delegate ritorna. L'archivio conservato finisce poi in `archives/`, come per il
selettore, quindi il fumetto si riapre dalla libreria senza sceglierlo di nuovo.

I dati dell'app (`archives/`, `covers/`) stanno nella cartella documenti su
mobile e in **Application Support** su desktop: su macOS `Documents` è la
cartella dell'utente, protetta dal consenso di sistema, dove una scrittura in
background fallisce senza dire nulla.

### Tempi di apertura

Il costo dominante **non** è l'estrazione (meno di un secondo su un CBZ da
223 MB) ma la lettura delle dimensioni di ogni pagina: ora si legge solo
l'**header** dell'immagine invece di decodificarla per intero (**18× più
veloce**). In più:

- la UI mostra il progresso reale (`Estrazione delle pagine… 42/150`) e resta
  reattiva;
- la prima apertura prepara le pagine, le successive sono **istantanee**
  (29,4 s → **0,65 s** sullo stesso CBZ);
- il comic è identificato dal **contenuto**, quindi la posizione di lettura
  viene ritrovata anche se il file è stato copiato altrove (è il caso di
  Android/iOS, dove il picker copia l'archivio in una cartella temporanea
diversa ogni volta).

## Libreria

La schermata iniziale è una **griglia degli ultimi fumetti aperti**: copertina,
titolo, barra di avanzamento con `Pagina 12 di 31 · 39%` e una **X** per
rimuoverli definitivamente.

- La copertina è la prima pagina ridimensionata a 400 px e salvata
  nell'archivio dell'app (`CoverCache`), non nella cartella temporanea.
- L'avanzamento è la stessa posizione di lettura salvata per file: la griglia
  la legge da `ReaderSettings`.
- Toccando una copertina il fumetto si riapre **senza l'archivio e senza
  riselezionare il file**: le pagine erano già estratte e il manifest basta a
  ricostruirlo. È anche il motivo per cui rimuoverlo dalla libreria è
  un'azione sensata: libera le pagine estratte (centinaia di MB).
- La libreria conserva una **copia propria dell'archivio** (in documents): su
  Android/iOS è semplicemente la copia che il picker fa nella cache, *spostata*
  invece che copiata, quindi non occupa spazio in più. Serve a ricostruire le
  pagine se il sistema pulisce la cartella temporanea: in quel caso la
  riapertura **re-estrae da sola**, mostrando il progresso, senza chiedere nulla.
  Si ri-seleziona il file solo se manca anche quella copia.
- Il file originale dell'utente non viene mai spostato né cancellato (su desktop
  la libreria usa direttamente il suo percorso).

## Icona dell'app

L'icona sorgente è `assets/icon/icon.png`. Dato che è un quadrato con angoli
arrotondati trasparenti e non è esattamente quadrata (610×588), un piccolo
script produce una sorgente quadrata 1024×1024 **opaca** (necessario per iOS),
riempiendo gli angoli con un gradiente campionato dai bordi dell'icona:

```bash
# 1. prepara la sorgente quadrata (→ assets/icon/icon_source.png)
dart run tool/generate_icon.dart

# 2. genera le icone di tutte le piattaforme
dart run flutter_launcher_icons
```

`flutter_launcher_icons` (configurato in `pubspec.yaml`) genera le icone per
Android, iOS (con `remove_alpha_ios`), macOS, Windows e web.

Il nome visibile dell'app è **ComicsNow** ovunque: bundle macOS (`PRODUCT_NAME`),
iOS (`CFBundleDisplayName`), etichetta Android, manifest web e titoli delle
finestre Windows/Linux.

## Modello di panel detection

L'app sceglie automaticamente il detector migliore disponibile
(`AppServices._createDetector`):

| Priorità | Condizione | Detector |
|---|---|---|
| 1 | `assets/models/panel_detector.onnx` presente | `OnnxPanelDetector` (macOS, Windows, Linux, Android, iOS) |
| 2 | in tutti gli altri casi | `GutterPanelDetector` (senza modello) |

All'avvio viene loggato il detector scelto e la schermata iniziale mostra
`Motore: ...`.

### Modello attualmente in uso

**Inkwell Panel Detector** — YOLOv8-nano, 1 classe (`panel`), input 640×640,
~3.800 pagine annotate. File: `assets/models/panel_detector.onnx` (12 MB).

Sui 15 sample di prova: **14/15 pagine con il numero esatto di vignette** con
soglia 0.35 (0.25 sovra-rileva, 0.50 non migliora). L'euristica senza modello si
fermava a 5/7 e sbagliava proprio i layout irregolari e i gutter scuri.

> **Licenza**: i pesi del detector sono **AGPL-3.0** (derivati da Ultralytics
> YOLOv8). Da valutare per un prodotto proprietario.

Dettagli, alternative valutate (Comic-Translate, Poneglyph, MosesB, Manga
YOLO26n) e prossimi passi sono in **[AGENTS.md](AGENTS.md)**.

## Modello ML su desktop (ONNX Runtime)

Il modello gira su **ONNX Runtime** (`flutter_onnxruntime`), disponibile su
macOS, Windows, Linux, Android e iOS.

> **Requisiti**: `flutter_onnxruntime` richiede **macOS 14+** e **iOS 16+**; i
target del progetto sono già allineati.

### Sostituire il modello

1. Esporta un modello di panel detection in ONNX, ad esempio con Ultralytics:

   ```bash
   yolo export model=best.pt format=onnx imgsz=640
   ```

   Va bene qualsiasi detection model con output YOLO-like: YOLOv8/v11
   (`[1, 4+nc, anchors]`), anchors-first (`[1, anchors, 4+nc]`), YOLOv5 con
   objectness, oppure export end-to-end con NMS (`[1, N, 6]`).

2. Copialo in `assets/models/panel_detector.onnx`.
3. Aggiorna `kOnnxModelVersion` in `lib/app_services.dart` (invalida la cache).
4. Se il modello non è un YOLOv8/v11 a 640px, configura `OnnxPanelDetector`:

   | Opzione | Quando |
   |---|---|
   | `hasObjectness: true` | output YOLOv5 (`[1, N, 5+nc]`) |
   | `isEndToEnd: true` | export con NMS già applicata (`[1, N, 6]`) |
   | `inputWidth` / `inputHeight` | modello con input diverso da 640 |
   | `classNames` / `targetClasses` | modello multi-classe |
   | `boxesAreNormalized` | se le box sono 0..1 invece che in pixel |

La geometria (letterbox), il parsing dell'output e la NMS sono in
`lib/detection/yolo_postprocess.dart` e sono coperti da unit test; il percorso
nativo è coperto da uno smoke test reale (vedi sotto).

### Smoke test del percorso nativo

```bash
flutter test integration_test/onnx_panel_detector_test.dart -d macos
```

Usa un modello sintetico (`assets/models/smoke_test_panel_detector.onnx`, 472
byte, output costante) per verificare che ONNX Runtime carichi un modello ed
esegua l'inferenza su macOS.

### Perché `flutter_onnxruntime` è vendored

Su **iOS** Xcode rifiuta il package SPM con:

```
Target Integrity: The package product 'flutter-onnxruntime-product' requires
minimum platform version 16.0 for the iOS platform, but this target supports 15.0
```

Causa verificata: Flutter genera
`ios/Flutter/ephemeral/Packages/FlutterGeneratedPluginSwiftPackage/Package.swift`
con `.iOS("15.0")` **fisso** e non lo alza, nemmeno con il deployment target
dell'app a 16.0: `flutter_tools` salta l'aggiornamento quando il target risolto
non supera il proprio default, e comunque il manifest viene rigenerato durante
il build. Quindi qualunque plugin SPM iOS che richieda > 15.0 fallisce.

Soluzione adottata:

- `flutter_onnxruntime` è **vendorizzato** in `third_party/flutter_onnxruntime`
  (1.8.5) con **il solo `ios/*/Package.swift` rimosso**: così su iOS il plugin
  passa da **CocoaPods** (podspec, iOS 16.0) e non dal package SPM generato;
- su **macOS** resta il Swift Package e quindi SPM, che già funzionava;
- `ios/Podfile` usa `use_frameworks! :linkage => :static`, richiesto da
  `onnxruntime-objc`.

Vedi `third_party/flutter_onnxruntime/VENDORED.md` per i dettagli e per quando
si può tornare alla versione pubblica.

### Perché `ultralytics_yolo` è stato rimosso

L'app includeva anche `ultralytics_yolo` (per modelli `.tflite`), che su iOS
trascina il pacchetto Swift di Ultralytics con la classe `CoreAIRequest`, basata
su **Apple Core AI (iOS 27+)**. Su iOS 26 la metadata Swift di quella classe
resta con un puntatore nullo e l'app **crasha all'avvio**, anche se Core AI non
viene mai usato:

```
type metadata completion function for CoreAIRequest.InputTensor
swift_getSingletonMetadata → objc_copyClassList → EXC_BAD_ACCESS 0x0
```

`ultralytics_yolo` non serve al progetto — il nostro modello è ONNX — quindi è
stato rimosso: meno dipendenze, meno superficie AGPL e niente crash.

### Avvio dell'app

`main()` **non** attende `AppServices.create()`: lancia subito l'app e crea i
servizi in un `FutureBuilder`, mostrando un indicatore mentre sono pronti. Così
un avvio lento (manifest degli asset, preferenze, handle del database) non è una
schermata vuota ma un loading visibile. `main.dart` logga `first frame at Xms` e
`services ready at Yms` per diagnosi.

### Debug o release su iOS

Per usare l'app toccando l'icona dalla home serve un build **release**:

```bash
flutter run --release        # oppure
flutter build ios --release
```

Il build **debug** è pensato per lo sviluppo con `flutter run` (JIT, hot reload,
binario più grande e lento) e non è adatto all'uso quotidiano.

### Niente più box prima dell'immagine

I viewport disegnavano le box dei pannelli subito e l'immagine solo quando
decodificata: si vedeva prima il layout e poi la pagina. Ora entrambi i viewport
(`PageViewport`, `PanelViewport`) aspettano il **primo frame** dell'immagine
(`ImageReadinessMixin`) e mostrano un indicatore finché non è pronta, così
pagina e box appaiono insieme. La pagina corrente viene anche precaricata
(`precacheImage`) appena il reader sa qual è.

L'attesa mostra `PageLoadingIndicator`: un indicatore **dedicato**, grande
(84 px) e animato — arco bianco che ruota e “respira” con un leggero battito di
scala, più l'etichetta `Pagina N`. Il `CircularProgressIndicator` di default era
piccolo e tinto con il colore del tema, quindi sul fondo nero del reader
sembrava un puntino. Con "Riduci movimento" attivo l'arco resta statico.

### Deployment target

| Piattaforma | Minimo | Dove |
|---|---|---|
| iOS | 16.0 | `IPHONEOS_DEPLOYMENT_TARGET` **in tutte** le configurazioni del pbxproj (progetto, Runner, RunnerTests) + `ios/Podfile` |
| macOS | 14.0 | `MACOSX_DEPLOYMENT_TARGET` + `macos/Podfile` |

Attenzione: in un progetto Flutter Xcode espone il target anche a **livello di
progetto**, oltre che di target. Se si alza solo il target (come si fa dalla UI
di Xcode) il valore di progetto resta indietro e Flutter genera il package SPM
con quello vecchio.

## Detector senza modello (fallback)

Quando non c'è nessun modello, l'app usa `GutterPanelDetector`: segmentazione
classica (XY-cut ricorsivo sui gutter) in puro Dart, senza modelli né plugin.
Funziona su 5 dei 7 sample di prova, incluse le pagine classiche italiane
(Dylan Dog: 4/6/6/5 vignette, tutte esatte).

Due accorgimenti lo rendono utilizzabile su pagine reali:

- **soglia adattiva** con il metodo di Otsu, perché le scansioni hanno gutter
grigi/tinti e non bianchi puri;
- **polarità adattiva**: il margine esterno della pagina decide se il fondo è
chiaro (fumetti classici, gutter bianchi) o scuro (pagine moderne dipinte,
gutter neri).

## Note per Android

- L'ONNX Runtime richiede la regola ProGuard
  `-keep class ai.onnxruntime.** { *; }`: è in `android/app/proguard-rules.pro`,
  già collegata a `buildTypes.release` in `android/app/build.gradle.kts`.
  Senza, il build release compila ma **crasha al primo caricamento del modello**.
- APK universale con ONNX ≈ 135 MB; per distribuirlo usa
  `flutter build apk --release --split-per-abi` (≈ 50 MB per ABI).
- L'avvio dipende dal dispositivo: su emulatore il tempo misurato da Android
  (`Displayed`) è dominato dall'avvio di processo + engine (~7 s) e dalla GPU
  software, non dal codice Dart. Il primo frame Dart arriva in ~1 s e **non**
  aspetta la creazione dei servizi (vedi sotto).

### Valutare il detector senza modello sui propri file

Metti le pagine in `samples/` con il numero atteso di vignette nel nome file,
es. `page-004 - 9 panels.jpg`, poi:

```bash
flutter test test/detection_samples_test.dart
```

Stampa una tabella (atteso vs rilevato) e salva le immagini annotate con le box
disegnate in `build/detection/`.

Note:

- La direzione di lettura predefinita è **sinistra→destra**
  (`kDefaultReadingDirection`), adatta a fumetti italiani/americani.
- Caricare un archivio grande (centinaia di MB) richiede tempo: le pagine
  vengono estratte su disco alla prima apertura.

### Licenza

I **pesi** del detector Inkwell sono **AGPL-3.0** (derivati da Ultralytics
YOLOv8), da risolvere prima di un prodotto proprietario/commerciale. Il runtime
ONNX Runtime e il codice dell'app non hanno lo stesso vincolo. Dettagli in
[AGENTS.md](AGENTS.md).

## Cache

La cache ha come chiave `(pageId, modelVersion)`:

```
page_id | model_version | panel_order | left | top | width | height | confidence | is_manual
```

Cambiando modello (nuova `modelVersion`) le detection vecchie non vengono
riusate silenziosamente.

## Prefetch

`PanelAnalysisQueue` analizza in anticipo le pagine successive:

```
pagina corrente → priorità 100
+1              → priorità  80
+2              → priorità  60
```

## Test

```bash
flutter test                                                  # unit + widget
flutter test integration_test/onnx_panel_detector_test.dart -d macos
flutter test integration_test/rar_extraction_test.dart -d macos \
  --dart-define=RAR_FIXTURE=$PWD/test/fixtures/sample.rar

# valutazione del modello reale sui sample (sweep di soglie)
flutter test integration_test/onnx_samples_test.dart -d macos \
  --dart-define=SAMPLES_DIR=$PWD/samples
```

Copre: ordinamento delle vignette, geometria dello zoom, **camera path** (zoom
logaritmico, punto focale lineare) e le **transizioni** del viewport (zoom,
dissolvenza, nessuna, "riduci movimento"), natural sort, lettura archivi
CBZ/CBR (ZIP reale + RAR con extractor iniettato, rilevamento del formato),
navigazione panel-by-panel e le tre modalità di lettura, preferenze persistenti
(modalità + posizione + comfort), pagina reader (slider, anteprima, callback di
posizione), pipeline di analisi + cache Drift in-memory, priorità e
deduplicazione della coda, segmentazione XY-cut, detector gutter su pagine
sintetiche, e tutta la logica YOLO/ONNX (letterbox, parsing dell'output, NMS,
mapping delle coordinate). Il test di integrazione verifica il percorso
nativo di ONNX Runtime su macOS.

## Prossimi passi

1. UI di correzione manuale delle vignette (aggiungi/elimina/modifica,
   `PageRepository.upsertPanel` / `removePanel` sono già pronti).
2. Benchmark su 100–200 pagine reali per scegliere/tarare il modello.
3. Caricamento pagina on-demand più aggressivo (LRU basato su byte, non su
   numero di pagine).
