# PLAN ADDENDUM — Taille de police adaptative (e-ink)

## Objectif

Calculer automatiquement une taille de police de base adaptée à la
résolution physique de l'écran au premier lancement, puis permettre
à l'utilisateur de l'ajuster avec des boutons **+** et **−** persistants.

---

## Package requis

```yaml
# Déjà présent dans pubspec.yaml :
device_info_plus: ^9.1.2   # ajouter si absent
```

Et le package Flutter natif `dart:ui` + `MediaQuery` — aucun package
supplémentaire requis pour la résolution physique.

---

## Étape A — Calcul de la taille de base

### Logique

La taille de police lisible sur e-ink dépend de deux facteurs :
- La **densité de pixels** (`devicePixelRatio`) — une liseuse e-ink 300 DPI
  a un ratio bien plus élevé qu'un téléphone bas de gamme
- La **taille physique de l'écran** (diagonale estimée en pouces)

Formule :
```
diagonale_px = sqrt(width_px² + height_px²)
dpi_estimé   = diagonale_px / diagonale_pouces_estimée
taille_base  = clamp(diagonale_px / 55, 14.0, 28.0)
```

En pratique, on se base sur `MediaQuery` (disponible au build time) :

```
width_dp  = MediaQuery.of(context).size.width
height_dp = MediaQuery.of(context).size.height
ratio     = MediaQuery.of(context).devicePixelRatio
diag_px   = sqrt((width_dp * ratio)² + (height_dp * ratio)²)
```

Table de correspondance visée :

| Appareil type        | Diag px (approx) | Taille base |
|----------------------|-----------------|-------------|
| Téléphone 5" 1080p   | ~2200 px        | 16 px       |
| Téléphone 6.5" 1080p | ~2600 px        | 17 px       |
| Boox Note 10.3" 1872p| ~3600 px        | 20 px       |
| Boox Tab 13.3" 2200p | ~4300 px        | 22 px       |
| Kindle Scribe 10.2"  | ~2300 px        | 18 px       |

Clamp final : **min 13 px, max 30 px**.

---

## Étape B — Modifier `SettingsService`

```dart
// lib/services/settings_service.dart

import 'dart:math';
import 'package:flutter/widgets.dart';

class SettingsService {
  static const _kEinkMode         = 'eink_mode';
  static const _kFontSize         = 'reader_font_size';
  static const _kFontSizeSet      = 'reader_font_size_set'; // jamais calculé auto ?
  static const _kArticlesPerPage  = 'articles_per_page';

  // ── font size ────────────────────────────────────────────────────────────

  /// Retourne la taille sauvegardée, ou null si jamais définie
  Future<double?> getSavedFontSize() async {
    final prefs = await SharedPreferences.getInstance();
    final set = prefs.getBool(_kFontSizeSet) ?? false;
    if (!set) return null;
    return prefs.getDouble(_kFontSize);
  }

  Future<void> setFontSize(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kFontSize, value);
    await prefs.setBool(_kFontSizeSet, true);
  }

  Future<void> resetFontSize() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kFontSize);
    await prefs.setBool(_kFontSizeSet, false);
  }

  // ── calcul adaptatif ─────────────────────────────────────────────────────

  /// Calcule la taille de police idéale pour cet écran.
  /// À appeler avec le BuildContext disponible (après le premier frame).
  static double computeAdaptiveFontSize(BuildContext context) {
    final mq = MediaQuery.of(context);
    final ratio = mq.devicePixelRatio;
    final widthPx  = mq.size.width  * ratio;
    final heightPx = mq.size.height * ratio;
    final diagPx   = sqrt(widthPx * widthPx + heightPx * heightPx);

    // Diviseur empirique : ajuster si nécessaire sur les appareils cibles
    final computed = diagPx / 130.0;

    return computed.clamp(13.0, 30.0).roundToDouble();
  }

  // ── autres settings ───────────────────────────────────────────────────────

  Future<bool>  getEinkMode()        async { ... }
  Future<void>  setEinkMode(bool v)  async { ... }
  Future<int>   getArticlesPerPage() async { ... }
}
```

---

## Étape C — Modifier `SettingsProvider`

```dart
// lib/providers/settings_provider.dart

class SettingsProvider extends ChangeNotifier {
  bool   einkMode        = false;
  double fontSize        = 17.0;   // valeur par défaut provisoire
  int    articlesPerPage = 4;
  bool   _fontSizeIsAuto = true;   // true = jamais ajusté manuellement

  final SettingsService _service = SettingsService();

  // ── chargement initial ────────────────────────────────────────────────────

  Future<void> load() async {
    einkMode        = await _service.getEinkMode();
    articlesPerPage = await _service.getArticlesPerPage();

    final saved = await _service.getSavedFontSize();
    if (saved != null) {
      fontSize        = saved;
      _fontSizeIsAuto = false;
    }
    // Si pas de taille sauvegardée → on garde 17 et on recalcule dans initFontSize()
    notifyListeners();
  }

  /// À appeler UNE FOIS après le premier frame, quand MediaQuery est disponible.
  /// Si l'utilisateur a déjà manuellement réglé la taille, ne fait rien.
  Future<void> initFontSize(BuildContext context) async {
    if (!_fontSizeIsAuto) return; // déjà défini manuellement → on respecte le choix
    final adaptive = SettingsService.computeAdaptiveFontSize(context);
    fontSize = adaptive;
    notifyListeners();
    // Ne pas sauvegarder ici : on recalcule à chaque lancement tant que
    // l'utilisateur n'a pas fait un réglage manuel
  }

  // ── réglage manuel ────────────────────────────────────────────────────────

  Future<void> increaseFontSize() async {
    if (fontSize >= 30) return;
    fontSize = (fontSize + 1).clamp(13.0, 30.0);
    _fontSizeIsAuto = false;
    await _service.setFontSize(fontSize);
    notifyListeners();
  }

  Future<void> decreaseFontSize() async {
    if (fontSize <= 13) return;
    fontSize = (fontSize - 1).clamp(13.0, 30.0);
    _fontSizeIsAuto = false;
    await _service.setFontSize(fontSize);
    notifyListeners();
  }

  /// Remet la taille auto calculée pour cet écran
  Future<void> resetFontSize(BuildContext context) async {
    await _service.resetFontSize();
    _fontSizeIsAuto = true;
    fontSize = SettingsService.computeAdaptiveFontSize(context);
    notifyListeners();
  }

  Future<void> toggleEinkMode() async { ... }
  bool get fontSizeIsAuto => _fontSizeIsAuto;
}
```

---

## Étape D — Appel de `initFontSize` au démarrage

Dans `lib/screens/home_screen.dart`, dans `initState` :

```dart
@override
void initState() {
  super.initState();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    // Calcul adaptatif au premier frame (MediaQuery disponible)
    context.read<SettingsProvider>().initFontSize(context);

    // Chargement du feed
    final sources = context.read<SourceProvider>().activeSources;
    context.read<FeedProvider>().refresh(sources);
  });
}
```

---

## Étape E — Boutons +/− dans le reader (`ArticleReaderScreen`)

Remplacer les IconButton `A+` / `A−` existants dans l'AppBar par des
boutons plus grands et plus clairs, avec affichage de la taille courante :

```dart
// Dans _ArticleReaderScreenState.build(), section actions de l'AppBar :

actions: [
  _FontSizeControls(),   // widget dédié ci-dessous
  IconButton(
    icon: const Icon(Icons.open_in_browser),
    onPressed: () => launchUrl(...),
  ),
],
```

```dart
// lib/widgets/font_size_controls.dart

class FontSizeControls extends StatelessWidget {
  const FontSizeControls({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Bouton −
        _FontButton(
          label: '−',
          enabled: settings.fontSize > 13,
          onTap: settings.decreaseFontSize,
        ),

        // Affichage taille courante + indicateur auto
        GestureDetector(
          onLongPress: () => _confirmReset(context, settings),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${settings.fontSize.toInt()}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  settings.fontSizeIsAuto ? 'auto' : 'manuel',
                  style: const TextStyle(
                    fontSize: 9,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Bouton +
        _FontButton(
          label: '+',
          enabled: settings.fontSize < 30,
          onTap: settings.increaseFontSize,
        ),

        const SizedBox(width: 4),
      ],
    );
  }

  void _confirmReset(BuildContext context, SettingsProvider settings) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Réinitialiser la taille ?'),
        content: Text(
          'Revenir à la taille calculée automatiquement '
          'pour cet écran (${SettingsService.computeAdaptiveFontSize(context).toInt()} px) ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              settings.resetFontSize(context);
              Navigator.pop(context);
            },
            child: const Text('Réinitialiser'),
          ),
        ],
      ),
    );
  }
}

class _FontButton extends StatelessWidget {
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  const _FontButton({
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          border: Border.all(
            color: enabled ? Colors.black : Colors.black26,
            width: 1,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: enabled ? Colors.black : Colors.black26,
          ),
        ),
      ),
    );
  }
}
```

---

## Étape F — Re-pagination à chaud

Quand `fontSize` change, le reader doit re-paginer SANS re-fetcher l'article.

Dans `_ArticleReaderScreenState`, stocker le contenu extrait :

```dart
// Ajouter dans le state :
ExtractedArticle? _extracted;
double _lastFontSize = 0;

// Modifier _loadArticle() :
Future<void> _loadArticle() async {
  // ...fetch...
  _extracted = extracted;
  _repaginate();   // appel centralisé
}

// Nouveau : _repaginate()
void _repaginate() {
  if (_extracted == null) return;
  final settings = context.read<SettingsProvider>();
  final screenSize = MediaQuery.of(context).size;

  final style = TextStyle(
    fontFamily: 'Georgia',
    fontSize: settings.fontSize,
    height: 1.6,
    color: Colors.black,
  );

  final pages = _paginator.paginate(
    text: _extracted!.content,
    pageSize: screenSize,
    style: style,
  );

  setState(() {
    _pages = pages;
    _currentPage = 0;           // retour à la page 1 après changement de taille
    _lastFontSize = settings.fontSize;
    _isLoading = false;
  });
}

// Dans didChangeDependencies() :
@override
void didChangeDependencies() {
  super.didChangeDependencies();
  final newSize = context.watch<SettingsProvider>().fontSize;
  if (_extracted != null && newSize != _lastFontSize) {
    _repaginate();
  }
}
```

---

## Étape G — Affichage dans SourcesTab (optionnel)

Remplacer le Slider existant par les boutons +/− cohérents avec le reader :

```dart
ListTile(
  title: const Text('Taille de police (lecteur)'),
  subtitle: Text(
    settings.fontSizeIsAuto
      ? 'Calculée automatiquement pour cet écran'
      : 'Réglée manuellement — appui long sur la taille pour réinitialiser',
    style: const TextStyle(fontSize: 11),
  ),
  trailing: const FontSizeControls(),
),
```

---

## Résumé des changements fichiers

| Fichier | Action |
|---|---|
| `lib/services/settings_service.dart` | Ajouter `computeAdaptiveFontSize()`, `getSavedFontSize()`, `resetFontSize()` |
| `lib/providers/settings_provider.dart` | Ajouter `initFontSize()`, `increaseFontSize()`, `decreaseFontSize()`, `resetFontSize()`, `fontSizeIsAuto` |
| `lib/screens/home_screen.dart` | Appeler `initFontSize(context)` dans `initState` post-frame |
| `lib/screens/article_reader_screen.dart` | Stocker `_extracted`, extraire `_repaginate()`, implémenter `didChangeDependencies()` |
| `lib/widgets/font_size_controls.dart` | **Nouveau fichier** — widget `FontSizeControls` + `_FontButton` |
| `lib/screens/sources_tab.dart` | Remplacer Slider par `FontSizeControls` |

---

## Checklist

- [ ] Premier lancement → taille calculée automatiquement selon l'écran
- [ ] Taille affichée avec label "auto"
- [ ] Bouton + → augmente d'1px, label passe à "manuel"
- [ ] Bouton − → diminue d'1px
- [ ] Boutons désactivés aux limites (13 et 30)
- [ ] Appui long sur le chiffre → dialog de réinitialisation
- [ ] Réinitialisation → recalcul adaptatif, label "auto"
- [ ] Changement de taille dans le reader → re-pagination immédiate
- [ ] Retour page 1 après re-pagination
- [ ] Taille manuelle persistée entre sessions
- [ ] Taille auto NON persistée (recalculée à chaque lancement)
