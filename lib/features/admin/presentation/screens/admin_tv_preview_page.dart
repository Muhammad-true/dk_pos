import 'dart:math' show min, max;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:dk_digitial_menu/core/app_config.dart' as dm_app_config;
import 'package:dk_digitial_menu/models/display_models.dart';
import 'package:dk_digitial_menu/models/tv_layout_config.dart';
import 'package:dk_digitial_menu/ui/tv3_shell_colors.dart';
import 'package:dk_digitial_menu/widgets/display_layout.dart';

import 'package:dk_pos/core/config/app_config.dart' as pos_app_config;
import 'package:dk_pos/core/error/api_exception.dart';
import 'package:dk_pos/features/admin/data/combos_admin_repository.dart';
import 'package:dk_pos/features/admin/data/menu_display_preview_repository.dart';
import 'package:dk_pos/features/admin/data/menu_items_admin_repository.dart';
import 'package:dk_pos/features/admin/data/screens_admin_repository.dart';
import 'package:dk_pos/features/admin/data/upload_repository.dart';
import 'package:dk_pos/features/admin/presentation/screens/tv2_screen_pages_editor_screen.dart';
import 'package:dk_pos/features/admin/presentation/screens/tv3_promo_pages_editor_screen.dart';
import 'package:dk_pos/features/admin/presentation/screens/tv4_slides_editor_screen.dart';
import 'package:dk_pos/l10n/app_localizations.dart';

Color _previewScaffoldBg(DisplayPayload p) => tv3PromoShellBackgroundColor(p);

Color _previewStageMarginColor(DisplayPayload p) =>
    tv3PromoPreviewStageMarginColor(p);

Color _previewStageUnderlay(DisplayPayload p) =>
    tv3PromoPreviewStageUnderlayColor(p);

/// Полноэкранный просмотр ТВ + панель «Оформление слайда» (carousel / tv2).
class AdminTvPreviewPage extends StatefulWidget {
  const AdminTvPreviewPage({
    super.key,
    required this.previewRepo,
    required this.requestBody,
    this.screensRepo,
  });

  final MenuDisplayPreviewRepository previewRepo;
  final Map<String, dynamic> requestBody;
  final ScreensAdminRepository? screensRepo;

  @override
  State<AdminTvPreviewPage> createState() => _AdminTvPreviewPageState();
}

class _AdminTvPreviewPageState extends State<AdminTvPreviewPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  DisplayPayload? _payload;
  Object? _error;
  bool _loading = true;

  late TvCarouselShow _cShow;
  late Tv2ListShow _t2Show;
  late String _transition;
  late List<String> _slotOrder;

  /// Смена страниц ТВ2: `tvLayout.tv2`.
  String _tv2PageTransition = 'slideUp';
  int _tv2PageHoldMs = 5000;
  int _tv2TransitionDurationMs = 400;
  bool _tv2VariedTransitions = false;
  String _tv2OverlayH = 'start';
  String _tv2OverlayV = 'bottom';

  late TextEditingController _cSlideBg;
  late TextEditingController _cHeaderBg;
  late TextEditingController _cHeaderText;
  late TextEditingController _cCategoryTitle;
  late TextEditingController _cCategorySubtitle;
  late TextEditingController _cItemName;
  late TextEditingController _cItemDesc;
  late TextEditingController _cItemPrice;
  late TextEditingController _cDivider;
  double _fontScale = 1.0;

  late TextEditingController _cTv3Header;
  late TextEditingController _cTv3PromoSlogan;
  late TextEditingController _cTv2Bg;
  late TextEditingController _cTv2Title;
  late TextEditingController _cTv2Price;
  late TextEditingController _cTv2HeaderText;
  late TextEditingController _cTv2Accent;
  double _tv2Scale = 1.0;
  double _tv2TitleSize = 0;
  double _tv2ItemNameSize = 0;
  late TextEditingController _cTv3Bg;
  late TextEditingController _cTv3Title;
  late TextEditingController _cTv3Price;
  late TextEditingController _cTv3HeaderText;
  late TextEditingController _cTv3Accent;
  double _tv3Scale = 1.0;
  /// `page3` | `promos`
  String _tv3LayoutMode = 'page3';

  /// Смена промо-слайдов ТВ3: `tvLayout.tv3` (актуально для режима «Акции»).
  String _tv3PageTransition = 'promoStack';
  int _tv3TransitionDurationMs = 920;

  /// Длительность показа одного слайда ТВ4 (сек), в конфиг сохраняется как `tv4SlideDurationMs`.
  int _tv4SlideDurationSec = 15;

  Map<String, dynamic>? _previewDraftBody;
  bool _saving = false;
  bool _forcedLandscapePreview = false;

  static Color _kfcRed() => const Color(0xFFE4002B);

  static Map<String, dynamic> _demoDraftSlides() => {
        'slides': [
          {
            'key': 'draft-demo',
            'sections': [
              {
                'id': 'cat-draft',
                'title': 'Черновик категории',
                'subtitle': 'Только для превью',
                'items': [
                  {
                    'id': 'd1',
                    'name': 'Позиция демо',
                    'priceText': '99',
                    'description': 'Состав / описание для проверки флагов',
                  },
                  {
                    'id': 'd2',
                    'name': 'Вторая позиция',
                    'priceText': '120',
                    'description': '',
                  },
                ],
              },
            ],
          },
        ],
      };

  @override
  void initState() {
    super.initState();
    _syncDigitalMenuMediaBaseWithPos();
    _cSlideBg = TextEditingController();
    _cHeaderBg = TextEditingController();
    _cHeaderText = TextEditingController();
    _cCategoryTitle = TextEditingController();
    _cCategorySubtitle = TextEditingController();
    _cItemName = TextEditingController();
    _cItemDesc = TextEditingController();
    _cItemPrice = TextEditingController();
    _cDivider = TextEditingController();
    _cTv3Header = TextEditingController();
    _cTv3PromoSlogan = TextEditingController();
    _cTv2Bg = TextEditingController();
    _cTv2Title = TextEditingController();
    _cTv2Price = TextEditingController();
    _cTv2HeaderText = TextEditingController();
    _cTv2Accent = TextEditingController();
    _cTv3Bg = TextEditingController();
    _cTv3Title = TextEditingController();
    _cTv3Price = TextEditingController();
    _cTv3HeaderText = TextEditingController();
    _cTv3Accent = TextEditingController();
    final cfg = widget.requestBody['config'];
    final base = cfg is Map<String, dynamic>
        ? Map<String, dynamic>.from(cfg)
        : <String, dynamic>{};
    final ht = base['tv3HeaderTitle'] ?? base['tv3_header_title'];
    if (ht is String) _cTv3Header.text = ht;
    final ps = base['tv3PromoSlogan'] ?? base['tv3_promo_slogan'];
    if (ps is String && ps.isNotEmpty) _cTv3PromoSlogan.text = ps;
    final ly = (base['tv3Layout'] ?? base['tv3_layout'] ?? 'page3').toString();
    _tv3LayoutMode = ly.toLowerCase().trim() == 'promos' ? 'promos' : 'page3';
    final r = TvLayoutResolved.fromScreenConfig(base);
    _cShow = r.carouselShow;
    _t2Show = r.tv2Show;
    _transition = r.carouselTransition;
    _slotOrder = List<String>.from(r.cardSlots.order);
    _hydrateStyleFields(r.carouselStyle);
    _hydrateTv2StyleFields(r.tv2Style);
    _hydrateTv3StyleFields(r.tv3Style);
    _hydrateTv3Timing(r);
    _hydrateTv2Timing(r);
    _hydrateTv2Overlay(r);
    _load();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeForceLandscapePreview());
  }

  Future<void> _maybeForceLandscapePreview() async {
    if (!mounted) return;
    final size = MediaQuery.sizeOf(context);
    if (size.shortestSide >= 600) return;
    _forcedLandscapePreview = true;
    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  void _hydrateTv2Timing(TvLayoutResolved r) {
    _tv2PageTransition = r.tv2PageTransition;
    _tv2PageHoldMs = r.tv2PageHoldMs ??
        (widget.requestBody['theme'] is Map
            ? (((widget.requestBody['theme'] as Map)['tvSlideRotationMs'] as num?)?.toInt() ?? 5000)
            : 5000);
    _tv2PageHoldMs = _tv2PageHoldMs.clamp(3000, 120000);
    _tv2TransitionDurationMs = r.tv2TransitionDurationMs ??
        tvCarouselTransitionDuration(_tv2PageTransition).inMilliseconds;
    _tv2TransitionDurationMs = _tv2TransitionDurationMs.clamp(200, 3000);
  }

  void _hydrateTv2Overlay(TvLayoutResolved r) {
    _tv2VariedTransitions = r.tv2VariedPageTransitionsWithVideo;
    _tv2OverlayH = r.tv2VideoOverlay.horizontal.name;
    _tv2OverlayV = r.tv2VideoOverlay.vertical.name;
  }

  @override
  void dispose() {
    _cSlideBg.dispose();
    _cHeaderBg.dispose();
    _cHeaderText.dispose();
    _cCategoryTitle.dispose();
    _cCategorySubtitle.dispose();
    _cItemName.dispose();
    _cItemDesc.dispose();
    _cItemPrice.dispose();
    _cDivider.dispose();
    _cTv3Header.dispose();
    _cTv3PromoSlogan.dispose();
    _cTv2Bg.dispose();
    _cTv2Title.dispose();
    _cTv2Price.dispose();
    _cTv2HeaderText.dispose();
    _cTv2Accent.dispose();
    _cTv3Bg.dispose();
    _cTv3Title.dispose();
    _cTv3Price.dispose();
    _cTv3HeaderText.dispose();
    _cTv3Accent.dispose();
    // После горизонтального превью на телефоне вернуть экран в портрет (не оставлять альбомку).
    if (_forcedLandscapePreview) {
      SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    }
    super.dispose();
  }

  void _hydrateStyleFields(TvCarouselStyle s) {
    _cSlideBg.text = s.slideBackgroundColor ?? '';
    _cHeaderBg.text = s.headerBackgroundColor ?? '';
    _cHeaderText.text = s.headerTextColor ?? '';
    _cCategoryTitle.text = s.categoryTitleColor ?? '';
    _cCategorySubtitle.text = s.categorySubtitleColor ?? '';
    _cItemName.text = s.itemNameColor ?? '';
    _cItemDesc.text = s.itemDescriptionColor ?? '';
    _cItemPrice.text = s.itemPriceColor ?? '';
    _cDivider.text = s.dividerColor ?? '';
    _fontScale = s.fontScale;
  }

  TvCarouselStyle _styleFromFields() {
    String? g(TextEditingController c) {
      final t = c.text.trim();
      return t.isEmpty ? null : t;
    }

    return TvCarouselStyle(
      slideBackgroundColor: g(_cSlideBg),
      headerBackgroundColor: g(_cHeaderBg),
      headerTextColor: g(_cHeaderText),
      categoryTitleColor: g(_cCategoryTitle),
      categorySubtitleColor: g(_cCategorySubtitle),
      itemNameColor: g(_cItemName),
      itemDescriptionColor: g(_cItemDesc),
      itemPriceColor: g(_cItemPrice),
      dividerColor: g(_cDivider),
      fontScale: _fontScale,
    );
  }

  void _hydrateTv2StyleFields(TvScreenStyle s) {
    _cTv2Bg.text = s.backgroundColor ?? '';
    _cTv2Title.text = s.titleColor ?? '';
    _cTv2Price.text = s.priceColor ?? '';
    _cTv2HeaderText.text = s.headerTextColor ?? '';
    _cTv2Accent.text = s.accentColor ?? '';
    _tv2Scale = s.scale;
    _tv2TitleSize = s.titleSize ?? 0;
    _tv2ItemNameSize = s.itemNameSize ?? 0;
  }

  void _hydrateTv3StyleFields(TvScreenStyle s) {
    _cTv3Bg.text = s.backgroundColor ?? '';
    _cTv3Title.text = s.titleColor ?? '';
    _cTv3Price.text = s.priceColor ?? '';
    _cTv3HeaderText.text = s.headerTextColor ?? '';
    _cTv3Accent.text = s.accentColor ?? '';
    _tv3Scale = s.scale;
  }

  void _hydrateTv3Timing(TvLayoutResolved r) {
    _tv3PageTransition = r.tv3PageTransition;
    _tv3TransitionDurationMs = r.tv3TransitionDurationMs ??
        resolvedTv3PromoTransitionDuration(r).inMilliseconds;
    if (_tv3PageTransition == 'none') {
      _tv3TransitionDurationMs = _tv3TransitionDurationMs.clamp(0, 3000);
    } else {
      _tv3TransitionDurationMs = _tv3TransitionDurationMs.clamp(200, 3000);
    }
  }

  TvScreenStyle _tv2StyleFromFields() {
    String? g(TextEditingController c) {
      final t = c.text.trim();
      return t.isEmpty ? null : t;
    }

    return TvScreenStyle(
      backgroundColor: g(_cTv2Bg),
      titleColor: g(_cTv2Title),
      priceColor: g(_cTv2Price),
      headerTextColor: g(_cTv2HeaderText),
      accentColor: g(_cTv2Accent),
      titleSize: _tv2TitleSize > 0 ? _tv2TitleSize : null,
      itemNameSize: _tv2ItemNameSize > 0 ? _tv2ItemNameSize : null,
      scale: _tv2Scale,
    );
  }

  TvScreenStyle _tv3StyleFromFields() {
    String? g(TextEditingController c) {
      final t = c.text.trim();
      return t.isEmpty ? null : t;
    }

    return TvScreenStyle(
      backgroundColor: g(_cTv3Bg),
      titleColor: g(_cTv3Title),
      priceColor: g(_cTv3Price),
      headerTextColor: g(_cTv3HeaderText),
      accentColor: g(_cTv3Accent),
      scale: _tv3Scale,
    );
  }

  void _resetTv2StyleFields() {
    setState(() {
      _hydrateTv2StyleFields(TvScreenStyle.empty);
    });
  }

  void _resetTv3StyleFields() {
    setState(() {
      _hydrateTv3StyleFields(TvScreenStyle.empty);
    });
  }

  static const List<String> _presetPalette = [
    '#FFFFFF',
    '#000000',
    '#E4002B',
    '#1A1A1A',
    '#F5F5F5',
    '#FFD54F',
    '#2E7D32',
    '#1565C0',
  ];

  void _pickColor(TextEditingController c, String value) {
    setState(() {
      c.text = value;
    });
  }

  /// [DigitalMenuDisplayLayout] берёт URL из `dk_digitial_menu` [AppConfig], у POS — свой
  /// статический origin; без синхронизации превью в админке грузит медиа с неверного хоста.
  void _syncDigitalMenuMediaBaseWithPos() {
    dm_app_config.AppConfig.setApiOriginOverride(pos_app_config.AppConfig.apiOrigin);
  }

  Future<void> _load() async {
    _syncDigitalMenuMediaBaseWithPos();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final body = Map<String, dynamic>.from(widget.requestBody);
      if (_previewDraftBody != null) {
        body['previewDraft'] = _previewDraftBody;
      }
      final baseCfg = body['config'] is Map
          ? Map<String, dynamic>.from(body['config'] as Map)
          : <String, dynamic>{};
      body['config'] = mergeScreenConfigMaps(baseCfg, _editorConfigPatch());
      final data = await widget.previewRepo.fetchPreview(body);
      if (!mounted) return;
      final p = DisplayPayload.fromJson(data);
      if (!mounted) return;
      setState(() {
        final firstPaint = _payload == null;
        _payload = p;
        if (firstPaint) {
          final r = TvLayoutResolved.fromScreenConfig(p.screenConfig);
          _cShow = r.carouselShow;
          _t2Show = r.tv2Show;
          _transition = r.carouselTransition;
          _slotOrder = List<String>.from(r.cardSlots.order);
          _hydrateStyleFields(r.carouselStyle);
          _hydrateTv2StyleFields(r.tv2Style);
          _hydrateTv3StyleFields(r.tv3Style);
          _hydrateTv3Timing(r);
          _hydrateTv2Timing(r);
          _hydrateTv2Overlay(r);
          if (p.screenType == 'tv3') {
            _cTv3Header.text = p.tv3HeaderTitle;
            _cTv3PromoSlogan.text = p.tv3PromoSlogan ?? '';
            _tv3LayoutMode = p.tv3Layout == 'promos' ? 'promos' : 'page3';
          }
          if (p.screenType == 'tv4') {
            final c = p.screenConfig;
            final ms = (c?['tv4SlideDurationMs'] ?? c?['tv4_slide_duration_ms']) as num?;
            final themeMs = p.theme.screenRotationMs.clamp(3000, 120000);
            final eff = (ms?.round() ?? themeMs).clamp(3000, 120000);
            _tv4SlideDurationSec = (eff / 1000).round().clamp(3, 120);
          }
        }
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Map<String, dynamic> _editorConfigPatch() {
    final st = _styleFromFields();
    final tv2Style = _tv2StyleFromFields();
    final tv3Style = _tv3StyleFromFields();
    final car = <String, dynamic>{
      'transition': _transition,
      'show': _cShow.toJson(),
      'slots': {'order': List<String>.from(_slotOrder)},
      'style': st.toJsonForApi(),
    };
    final patch = <String, dynamic>{
      'tvLayout': {
        'layoutVersion': 1,
        'carousel': car,
        'tv2': {
          'show': _t2Show.toJson(),
          'style': tv2Style.toJsonForApi(),
          'pageTransition': _tv2PageTransition,
          'pageHoldMs': _tv2PageHoldMs,
          'transitionDurationMs': _tv2TransitionDurationMs,
          'variedPageTransitionsWithVideo': _tv2VariedTransitions,
          'videoOverlay': {
            'horizontal': _tv2OverlayH,
            'vertical': _tv2OverlayV,
          },
        },
        'tv3': {
          'style': tv3Style.toJsonForApi(),
          'pageTransition': _tv3PageTransition,
          'transitionDurationMs': _tv3TransitionDurationMs,
        },
      },
      'tv3HeaderTitle': _cTv3Header.text.trim(),
      'tv3PromoSlogan': _cTv3PromoSlogan.text.trim(),
      'tv3Layout': _tv3LayoutMode,
    };
    if (_payload?.screenType == 'tv4') {
      patch['tv4SlideDurationMs'] = (_tv4SlideDurationSec * 1000).clamp(3000, 120000);
    }
    return patch;
  }

  Map<String, dynamic> _liveScreenConfig() {
    final base = _payload?.screenConfig != null
        ? Map<String, dynamic>.from(_payload!.screenConfig!)
        : (widget.requestBody['config'] is Map
            ? Map<String, dynamic>.from(widget.requestBody['config'] as Map)
            : <String, dynamic>{});
    return mergeScreenConfigMaps(base, _editorConfigPatch());
  }

  DisplayPayload? _payloadForDisplay() {
    final p = _payload;
    if (p == null) return null;
    var merged = p.copyWith(screenConfig: _liveScreenConfig());
    if (merged.screenType == 'tv3') {
      final t = _cTv3Header.text.trim();
      final ps = _cTv3PromoSlogan.text.trim();
      merged = merged.copyWith(
        tv3HeaderTitle: t,
        tv3Layout: _tv3LayoutMode,
        tv3PromoSlogan: ps.isEmpty ? null : ps,
        clearTv3PromoSlogan: ps.isEmpty,
      );
    }
    if (merged.screenType == 'tv4' && merged.tv4 != null) {
      final ms = (_tv4SlideDurationSec * 1000).clamp(3000, 120000);
      merged = merged.copyWith(
        tv4: merged.tv4!.withSlideDurationOverride(ms),
      );
    }
    return merged;
  }

  Future<void> _saveToScreen() async {
    final l10n = AppLocalizations.of(context)!;
    final repo = widget.screensRepo;
    final id = _payload?.screenId ?? 0;
    if (repo == null || id < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.adminTvSlideNoScreenId)),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final updated = await repo.mergeScreenConfig(id, _editorConfigPatch());
      if (!mounted) return;
      final p = _payload;
      if (p != null && updated.config != null) {
        setState(() {
          _payload = p.copyWith(
            screenConfig: Map<String, dynamic>.from(updated.config!),
          );
          if (p.screenType == 'tv2') {
            final r = TvLayoutResolved.fromScreenConfig(_payload!.screenConfig);
            _hydrateTv2Timing(r);
            _hydrateTv2Overlay(r);
          }
        });
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.adminTvSlideSaved)),
      );
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.adminTvSlideSaveError)),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveDraftToServer() async {
    final l10n = AppLocalizations.of(context)!;
    final repo = widget.screensRepo;
    final id = _payload?.screenId ?? 0;
    if (repo == null || id < 1 || _previewDraftBody == null) return;
    setState(() => _saving = true);
    try {
      await repo.mergeScreenConfig(id, {'previewDraft': _previewDraftBody});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.adminTvDraftSavedToConfig)),
      );
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _applyPreset(String? key) {
    if (key == null) return;
    final raw = tvLayoutPresets[key];
    if (raw == null) return;
    final r = TvLayoutResolved.fromScreenConfig({'tvLayout': raw});
    setState(() {
      _cShow = r.carouselShow;
      _t2Show = r.tv2Show;
      _transition = r.carouselTransition;
      _slotOrder = List<String>.from(r.cardSlots.order);
      _hydrateTv2Timing(r);
      _hydrateTv2Overlay(r);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (_loading) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: _kfcRed(),
          foregroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            tooltip: l10n.adminTvPreviewClose,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null && _payload == null) {
      final msg = _error is ApiException
          ? (_error! as ApiException).message
          : _error.toString();
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: _kfcRed(),
          foregroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            tooltip: l10n.adminTvPreviewClose,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.adminTvPreviewError,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(msg, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _load,
                  child: Text(l10n.adminTvPreviewRetry),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final displayPayload = _payloadForDisplay();
    if (displayPayload == null) {
      return const SizedBox.shrink();
    }

    final isCarousel = displayPayload.screenType == 'carousel';
    final isTv3 = displayPayload.screenType == 'tv3';
    final isTv4 = displayPayload.screenType == 'tv4';
    final canSave = (widget.screensRepo != null) && (displayPayload.screenId > 0);

    final mqSize = MediaQuery.sizeOf(context);
    final drawerWidth = mqSize.shortestSide < 600
        ? min(max(mqSize.width - 16, 200.0), mqSize.width)
        : 320.0;

    Widget scaffold = Scaffold(
      key: _scaffoldKey,
      backgroundColor: _previewScaffoldBg(displayPayload),
      endDrawer: Drawer(
        width: drawerWidth,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                l10n.adminTvSlideAppearanceTitle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: 'custom',
                decoration: InputDecoration(
                  labelText: l10n.adminTvPresetLabel,
                  border: const OutlineInputBorder(),
                ),
                items: [
                  DropdownMenuItem(value: 'custom', child: Text(l10n.adminTvPresetCustom)),
                  DropdownMenuItem(value: 'default', child: Text(l10n.adminTvPresetDefault)),
                  DropdownMenuItem(value: 'compact', child: Text(l10n.adminTvPresetCompact)),
                  DropdownMenuItem(value: 'bold', child: Text(l10n.adminTvPresetBold)),
                ],
                onChanged: (v) {
                  if (v == null || v == 'custom') return;
                  _applyPreset(v);
                },
              ),
              const SizedBox(height: 16),
              if (isCarousel) ...[
                Text(l10n.adminTvTransition, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  key: ValueKey<String>(_transition),
                  initialValue: _transition,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    DropdownMenuItem(value: 'fade', child: Text(l10n.adminTvTransitionFade)),
                    DropdownMenuItem(value: 'slide', child: Text(l10n.adminTvTransitionSlide)),
                    DropdownMenuItem(value: 'crossFade', child: Text(l10n.adminTvTransitionCrossFade)),
                    DropdownMenuItem(value: 'none', child: Text(l10n.adminTvTransitionNone)),
                    DropdownMenuItem(value: 'scale', child: Text(l10n.adminTvTransitionScale)),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _transition = v);
                  },
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: Text(l10n.adminTvCategorySubtitle),
                  value: _cShow.categorySubtitle,
                  onChanged: (x) => setState(() => _cShow = TvCarouselShow(
                        categorySubtitle: x,
                        itemPrice: _cShow.itemPrice,
                        itemDivider: _cShow.itemDivider,
                        itemDescription: _cShow.itemDescription,
                      )),
                ),
                SwitchListTile(
                  title: Text(l10n.adminTvItemPrice),
                  value: _cShow.itemPrice,
                  onChanged: (x) => setState(() => _cShow = TvCarouselShow(
                        categorySubtitle: _cShow.categorySubtitle,
                        itemPrice: x,
                        itemDivider: _cShow.itemDivider,
                        itemDescription: _cShow.itemDescription,
                      )),
                ),
                SwitchListTile(
                  title: Text(l10n.adminTvItemDivider),
                  value: _cShow.itemDivider,
                  onChanged: (x) => setState(() => _cShow = TvCarouselShow(
                        categorySubtitle: _cShow.categorySubtitle,
                        itemPrice: _cShow.itemPrice,
                        itemDivider: x,
                        itemDescription: _cShow.itemDescription,
                      )),
                ),
                SwitchListTile(
                  title: Text(l10n.adminTvItemDescription),
                  value: _cShow.itemDescription,
                  onChanged: (x) => setState(() => _cShow = TvCarouselShow(
                        categorySubtitle: _cShow.categorySubtitle,
                        itemPrice: _cShow.itemPrice,
                        itemDivider: _cShow.itemDivider,
                        itemDescription: x,
                      )),
                ),
                const SizedBox(height: 16),
                Text(l10n.adminTvStyleTitle, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(l10n.adminTvStyleHexHint, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 8),
                TextField(
                  controller: _cSlideBg,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: l10n.adminTvStyleSlideBg,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _cHeaderBg,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: l10n.adminTvStyleHeaderBg,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _cHeaderText,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: l10n.adminTvStyleHeaderText,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _cCategoryTitle,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: l10n.adminTvStyleCategoryTitle,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _cCategorySubtitle,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: l10n.adminTvStyleCategorySubtitle,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _cItemName,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: l10n.adminTvStyleItemName,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _cItemDesc,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: l10n.adminTvStyleItemDesc,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _cItemPrice,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: l10n.adminTvStyleItemPrice,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _cDivider,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: l10n.adminTvStyleDivider,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '${l10n.adminTvStyleFontScale} (${_fontScale.toStringAsFixed(2)}×)',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                Slider(
                  value: _fontScale.clamp(0.65, 1.5),
                  min: 0.65,
                  max: 1.5,
                  divisions: 17,
                  onChanged: (v) => setState(() => _fontScale = v),
                ),
                OutlinedButton(
                  onPressed: () => setState(() {
                    _hydrateStyleFields(TvCarouselStyle.empty);
                  }),
                  child: Text(l10n.adminTvStyleReset),
                ),
                const SizedBox(height: 8),
                Text(l10n.adminTvSlotsTitle, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(l10n.adminTvSlotsHint, style: Theme.of(context).textTheme.bodySmall),
                ReorderableListView(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  onReorder: (a, b) {
                    setState(() {
                      if (b > a) b -= 1;
                      final x = _slotOrder.removeAt(a);
                      _slotOrder.insert(b, x);
                    });
                  },
                  children: [
                    for (var i = 0; i < _slotOrder.length; i++)
                      ListTile(
                        key: ValueKey('${_slotOrder[i]}-$i'),
                        title: Text(_slotOrder[i]),
                        leading: const Icon(Icons.drag_handle_rounded),
                      ),
                  ],
                ),
              ] else if (isTv3) ...[
                Text(
                  l10n.adminTv3AppearanceTitle,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _cTv3Header,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: l10n.adminTv3HeaderTitleLabel,
                    helperText: l10n.adminTv3HeaderTitleHint,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _cTv3PromoSlogan,
                  onChanged: (_) => setState(() {}),
                  maxLength: 120,
                  decoration: InputDecoration(
                    labelText: l10n.adminTv3PromoSloganLabel,
                    helperText: l10n.adminTv3PromoSloganHint,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  key: ValueKey<String>(_tv3LayoutMode),
                  initialValue: _tv3LayoutMode,
                  decoration: InputDecoration(
                    labelText: l10n.adminTv3LayoutLabel,
                    border: const OutlineInputBorder(),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 'page3',
                      child: Text(l10n.adminTv3LayoutPage3),
                    ),
                    DropdownMenuItem(
                      value: 'promos',
                      child: Text(l10n.adminTv3LayoutPromos),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _tv3LayoutMode = v);
                  },
                ),
                if (_tv3LayoutMode == 'promos') ...[
                  const SizedBox(height: 12),
                  Text(
                    l10n.adminTv2PageTransitionLabel,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    key: ValueKey<String>(_tv3PageTransition),
                    initialValue: _tv3PageTransition,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: 'promoStack',
                        child: const Text('ТВ3 «снизу» (классика)'),
                      ),
                      DropdownMenuItem(
                        value: 'fade',
                        child: Text(l10n.adminTvTransitionFade),
                      ),
                      DropdownMenuItem(
                        value: 'slide',
                        child: Text(l10n.adminTvTransitionSlide),
                      ),
                      DropdownMenuItem(
                        value: 'crossFade',
                        child: Text(l10n.adminTvTransitionCrossFade),
                      ),
                      DropdownMenuItem(
                        value: 'none',
                        child: Text(l10n.adminTvTransitionNone),
                      ),
                      DropdownMenuItem(
                        value: 'scale',
                        child: Text(l10n.adminTvTransitionScale),
                      ),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() {
                        _tv3PageTransition = v;
                        final tmp = TvLayoutResolved.fromScreenConfig({
                          'tvLayout': {
                            'layoutVersion': 1,
                            'carousel': {'transition': 'fade'},
                            'tv2': <String, dynamic>{},
                            'tv3': {'pageTransition': v},
                          },
                        });
                        _hydrateTv3Timing(tmp);
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(l10n.adminTv2TransitionDurationLabel(_tv3TransitionDurationMs)),
                  Slider(
                    value: _tv3TransitionDurationMs.toDouble().clamp(
                      _tv3PageTransition == 'none' ? 0 : 200,
                      3000,
                    ),
                    min: _tv3PageTransition == 'none' ? 0 : 200,
                    max: 3000,
                    divisions: _tv3PageTransition == 'none' ? 30 : 28,
                    label: '$_tv3TransitionDurationMs ms',
                    onChanged: _tv3PageTransition == 'none'
                        ? null
                        : (v) => setState(() => _tv3TransitionDurationMs = v.round()),
                  ),
                ],
                const SizedBox(height: 12),
                Text('Стиль ТВ3 (#RRGGBB)', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                _ColorPaletteField(
                  label: 'Фон',
                  selectedHex: _cTv3Bg.text,
                  palette: _presetPalette,
                  onSelect: (v) => _pickColor(_cTv3Bg, v),
                ),
                const SizedBox(height: 8),
                _ColorPaletteField(
                  label: 'Цвет заголовка',
                  selectedHex: _cTv3Title.text,
                  palette: _presetPalette,
                  onSelect: (v) => _pickColor(_cTv3Title, v),
                ),
                const SizedBox(height: 8),
                _ColorPaletteField(
                  label: 'Цвет цены',
                  selectedHex: _cTv3Price.text,
                  palette: _presetPalette,
                  onSelect: (v) => _pickColor(_cTv3Price, v),
                ),
                const SizedBox(height: 8),
                _ColorPaletteField(
                  label: 'Цвет текста шапки',
                  selectedHex: _cTv3HeaderText.text,
                  palette: _presetPalette,
                  onSelect: (v) => _pickColor(_cTv3HeaderText, v),
                ),
                const SizedBox(height: 8),
                _ColorPaletteField(
                  label: 'Акцентный цвет',
                  selectedHex: _cTv3Accent.text,
                  palette: _presetPalette,
                  onSelect: (v) => _pickColor(_cTv3Accent, v),
                ),
                const SizedBox(height: 8),
                Text('Масштаб (${_tv3Scale.toStringAsFixed(2)}x)'),
                Slider(
                  value: _tv3Scale.clamp(0.65, 1.8),
                  min: 0.65,
                  max: 1.8,
                  divisions: 23,
                  onChanged: (v) => setState(() => _tv3Scale = v),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: _resetTv3StyleFields,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Сбросить стиль ТВ3'),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.adminTv3ContentHint,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                if (canSave) ...[
                  FilledButton.tonal(
                    onPressed: () async {
                      final nav = Navigator.of(context, rootNavigator: true);
                      await nav.push<void>(
                        MaterialPageRoute<void>(
                          builder: (_) => Tv3PromoPagesEditorScreen(
                            screenId: displayPayload.screenId,
                            screensRepo: widget.screensRepo!,
                            menuRepo: context.read<MenuItemsAdminRepository>(),
                            combosRepo: context.read<CombosAdminRepository>(),
                            uploadRepo: context.read<UploadRepository>(),
                          ),
                        ),
                      );
                      if (context.mounted) await _load();
                    },
                    child: Text(l10n.adminTv3OpenPromoPagesEditor),
                  ),
                ],
              ] else if (isTv4) ...[
                Text(
                  l10n.adminTv4SlidesEditorSubtitle,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.adminTv4SlideDurationLabel,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Slider(
                  value: _tv4SlideDurationSec.toDouble().clamp(3, 120),
                  min: 3,
                  max: 120,
                  divisions: 117,
                  label: '${_tv4SlideDurationSec}s',
                  onChanged: (v) => setState(() => _tv4SlideDurationSec = v.round()),
                ),
                const SizedBox(height: 12),
                if (canSave) ...[
                  FilledButton.tonal(
                    onPressed: () async {
                      final nav = Navigator.of(context, rootNavigator: true);
                      await nav.push<void>(
                        MaterialPageRoute<void>(
                          builder: (_) => Tv4SlidesEditorScreen(
                            screenId: displayPayload.screenId,
                            screensRepo: widget.screensRepo!,
                          ),
                        ),
                      );
                      if (context.mounted) await _load();
                    },
                    child: Text(l10n.adminTv4OpenSlidesEditor),
                  ),
                ],
              ] else ...[
                if (canSave) ...[
                  FilledButton.tonal(
                    onPressed: () async {
                      final nav = Navigator.of(context, rootNavigator: true);
                      await nav.push<void>(
                        MaterialPageRoute<void>(
                          builder: (_) => Tv2ScreenPagesEditorScreen(
                            screenId: displayPayload.screenId,
                            screensRepo: widget.screensRepo!,
                            menuRepo: context.read<MenuItemsAdminRepository>(),
                            combosRepo: context.read<CombosAdminRepository>(),
                            uploadRepo: context.read<UploadRepository>(),
                          ),
                        ),
                      );
                      if (context.mounted) {
                        await _load();
                        await _maybeForceLandscapePreview();
                      }
                    },
                    child: Text(l10n.adminTv2OpenPagesEditor),
                  ),
                  const SizedBox(height: 16),
                ],
                Text('Стиль ТВ2 (#RRGGBB)', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                _ColorPaletteField(
                  label: 'Фон',
                  selectedHex: _cTv2Bg.text,
                  palette: _presetPalette,
                  onSelect: (v) => _pickColor(_cTv2Bg, v),
                ),
                const SizedBox(height: 8),
                _ColorPaletteField(
                  label: 'Цвет заголовка',
                  selectedHex: _cTv2Title.text,
                  palette: _presetPalette,
                  onSelect: (v) => _pickColor(_cTv2Title, v),
                ),
                const SizedBox(height: 8),
                _ColorPaletteField(
                  label: 'Цвет цены',
                  selectedHex: _cTv2Price.text,
                  palette: _presetPalette,
                  onSelect: (v) => _pickColor(_cTv2Price, v),
                ),
                const SizedBox(height: 8),
                _ColorPaletteField(
                  label: 'Цвет текста шапки',
                  selectedHex: _cTv2HeaderText.text,
                  palette: _presetPalette,
                  onSelect: (v) => _pickColor(_cTv2HeaderText, v),
                ),
                const SizedBox(height: 8),
                _ColorPaletteField(
                  label: 'Акцентный цвет',
                  selectedHex: _cTv2Accent.text,
                  palette: _presetPalette,
                  onSelect: (v) => _pickColor(_cTv2Accent, v),
                ),
                const SizedBox(height: 8),
                Text('Размер заголовка: ${_tv2TitleSize > 0 ? _tv2TitleSize.toStringAsFixed(0) : 'по умолчанию'}'),
                Slider(
                  value: ((_tv2TitleSize > 0 ? _tv2TitleSize : 40).clamp(16, 120)).toDouble(),
                  min: 16,
                  max: 120,
                  divisions: 52,
                  onChanged: (v) => setState(() => _tv2TitleSize = v),
                ),
                Text('Размер названия товара: ${_tv2ItemNameSize > 0 ? _tv2ItemNameSize.toStringAsFixed(0) : 'по умолчанию'}'),
                Slider(
                  value: ((_tv2ItemNameSize > 0 ? _tv2ItemNameSize : 32).clamp(12, 96)).toDouble(),
                  min: 12,
                  max: 96,
                  divisions: 42,
                  onChanged: (v) => setState(() => _tv2ItemNameSize = v),
                ),
                TextButton(
                  onPressed: () => setState(() {
                    _tv2TitleSize = 0;
                    _tv2ItemNameSize = 0;
                  }),
                  child: const Text('Сбросить размеры ТВ2'),
                ),
                const SizedBox(height: 4),
                Text('Масштаб (${_tv2Scale.toStringAsFixed(2)}x)'),
                Slider(
                  value: _tv2Scale.clamp(0.65, 1.8),
                  min: 0.65,
                  max: 1.8,
                  divisions: 23,
                  onChanged: (v) => setState(() => _tv2Scale = v),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: _resetTv2StyleFields,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Сбросить стиль ТВ2'),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.adminTv2PagesTimingTitle,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.adminTv2PagesTimingHint,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  key: ValueKey<String>(_tv2PageTransition),
                  initialValue: _tv2PageTransition,
                  decoration: InputDecoration(
                    labelText: l10n.adminTv2PageTransitionLabel,
                    border: const OutlineInputBorder(),
                  ),
                  items: [
                    DropdownMenuItem(value: 'fade', child: Text(l10n.adminTvTransitionFade)),
                    DropdownMenuItem(
                      value: 'slideUp',
                      child: Text(l10n.adminTvTransitionSlideUp),
                    ),
                    DropdownMenuItem(value: 'slide', child: Text(l10n.adminTvTransitionSlide)),
                    DropdownMenuItem(value: 'crossFade', child: Text(l10n.adminTvTransitionCrossFade)),
                    DropdownMenuItem(value: 'none', child: Text(l10n.adminTvTransitionNone)),
                    DropdownMenuItem(value: 'scale', child: Text(l10n.adminTvTransitionScale)),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _tv2PageTransition = v);
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.adminTv2PageHoldLabel((_tv2PageHoldMs / 1000).round()),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                Slider(
                  value: (_tv2PageHoldMs / 1000).clamp(3, 120),
                  min: 3,
                  max: 120,
                  divisions: 117,
                  label: '${(_tv2PageHoldMs / 1000).round()} с',
                  onChanged: (v) =>
                      setState(() => _tv2PageHoldMs = (v * 1000).round()),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.adminTv2TransitionDurationLabel(_tv2TransitionDurationMs),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                Slider(
                  value: _tv2TransitionDurationMs.toDouble().clamp(200, 3000),
                  min: 200,
                  max: 3000,
                  divisions: 56,
                  label: '$_tv2TransitionDurationMs ms',
                  onChanged: _tv2PageTransition == 'none'
                      ? null
                      : (v) => setState(() => _tv2TransitionDurationMs = v.round()),
                ),
                SwitchListTile(
                  title: Text(l10n.adminTv2VariedTransitionsTitle),
                  subtitle: Text(
                    l10n.adminTv2VariedTransitionsSubtitle,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  value: _tv2VariedTransitions,
                  onChanged: (v) => setState(() => _tv2VariedTransitions = v),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.adminTv2VideoOverlayTitle,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  key: ValueKey<String>('ovh-$_tv2OverlayH'),
                  initialValue: _tv2OverlayH,
                  decoration: InputDecoration(
                    labelText: l10n.adminTv2VideoOverlayHorizontal,
                    border: const OutlineInputBorder(),
                  ),
                  items: [
                    DropdownMenuItem(value: 'start', child: Text(l10n.adminTv2AlignStart)),
                    DropdownMenuItem(value: 'center', child: Text(l10n.adminTv2AlignCenter)),
                    DropdownMenuItem(value: 'end', child: Text(l10n.adminTv2AlignEnd)),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _tv2OverlayH = v);
                  },
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  key: ValueKey<String>('ovv-$_tv2OverlayV'),
                  initialValue: _tv2OverlayV,
                  decoration: InputDecoration(
                    labelText: l10n.adminTv2VideoOverlayVertical,
                    border: const OutlineInputBorder(),
                  ),
                  items: [
                    DropdownMenuItem(value: 'bottom', child: Text(l10n.adminTv2AlignBottom)),
                    DropdownMenuItem(value: 'center', child: Text(l10n.adminTv2AlignMiddle)),
                    DropdownMenuItem(value: 'top', child: Text(l10n.adminTv2AlignTop)),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _tv2OverlayV = v);
                  },
                ),
                const SizedBox(height: 16),
                Text(l10n.adminTv2ListAppearance, style: Theme.of(context).textTheme.titleSmall),
                SwitchListTile(
                  title: Text(l10n.adminTv2ItemImage),
                  value: _t2Show.itemImage,
                  onChanged: (x) => setState(() => _t2Show = Tv2ListShow(
                        itemImage: x,
                        itemPrice: _t2Show.itemPrice,
                        itemDescription: _t2Show.itemDescription,
                      )),
                ),
                SwitchListTile(
                  title: Text(l10n.adminTvItemPrice),
                  value: _t2Show.itemPrice,
                  onChanged: (x) => setState(() => _t2Show = Tv2ListShow(
                        itemImage: _t2Show.itemImage,
                        itemPrice: x,
                        itemDescription: _t2Show.itemDescription,
                      )),
                ),
                SwitchListTile(
                  title: Text(l10n.adminTvItemDescription),
                  value: _t2Show.itemDescription,
                  onChanged: (x) => setState(() => _t2Show = Tv2ListShow(
                        itemImage: _t2Show.itemImage,
                        itemPrice: _t2Show.itemPrice,
                        itemDescription: x,
                      )),
                ),
              ],
              const Divider(height: 32),
              Text(l10n.adminTvDraftTitle, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Text(l10n.adminTvDraftHint, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 8),
              if (isCarousel) ...[
                FilledButton.tonal(
                  onPressed: () {
                    setState(() => _previewDraftBody = _demoDraftSlides());
                    _load();
                  },
                  child: Text(l10n.adminTvDraftApply),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () {
                    setState(() => _previewDraftBody = null);
                    _load();
                  },
                  child: Text(l10n.adminTvDraftReset),
                ),
                if (canSave && _previewDraftBody != null) ...[
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _saving ? null : _saveDraftToServer,
                    child: Text(l10n.adminTvDraftSaveToConfig),
                  ),
                ],
              ],
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: (_saving || !canSave) ? null : _saveToScreen,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_rounded),
                label: Text(_saving ? l10n.adminTvSlideSaving : l10n.adminTvSlideSaveToScreen),
              ),
              if (!canSave)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    l10n.adminTvSlideNoScreenId,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
            ],
          ),
        ),
      ),
      body: _AdminTvPreviewStage(
        displayPayload: displayPayload,
        l10n: l10n,
        onClose: () => Navigator.of(context).pop(),
        onOpenSettings: () => _scaffoldKey.currentState?.openEndDrawer(),
      ),
    );

    return scaffold;
  }
}

class _ColorPaletteField extends StatelessWidget {
  const _ColorPaletteField({
    required this.label,
    required this.selectedHex,
    required this.palette,
    required this.onSelect,
  });

  final String label;
  final String selectedHex;
  final List<String> palette;
  final ValueChanged<String> onSelect;

  Color _hexToColor(String hex) {
    final v = parseTvLayoutHexColor(hex);
    return v ?? Colors.transparent;
  }

  @override
  Widget build(BuildContext context) {
    final selected = selectedHex.trim().toUpperCase();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final hex in palette)
              InkWell(
                onTap: () => onSelect(hex),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: _hexToColor(hex),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: selected == hex ? const Color(0xFFE4002B) : Colors.black26,
                      width: selected == hex ? 2 : 1,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Кадр превью ТВ: соотношение 16:9 по центру; на телефоне — масштаб двумя пальцами.
class _AdminTvPreviewStage extends StatelessWidget {
  const _AdminTvPreviewStage({
    required this.displayPayload,
    required this.l10n,
    required this.onClose,
    required this.onOpenSettings,
  });

  final DisplayPayload displayPayload;
  final AppLocalizations l10n;
  final VoidCallback onClose;
  final VoidCallback onOpenSettings;

  static const double _kTvAspect = 16 / 9;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth;
        final maxH = constraints.maxHeight;
        final narrow = MediaQuery.sizeOf(context).shortestSide < 600;
        final isPortraitPhone = narrow && maxH > maxW;
        late final double w;
        late final double h;
        if (isPortraitPhone) {
          h = min((maxW - 16).clamp(1.0, maxW), ((maxH - 16) * 9 / 16).clamp(1.0, maxW));
          w = h * _kTvAspect;
        } else {
          var fitW = (maxW - 16).clamp(1.0, maxW);
          var fitH = fitW / _kTvAspect;
          if (fitH > maxH - 16) {
            fitH = (maxH - 16).clamp(1.0, maxH);
            fitW = fitH * _kTvAspect;
          }
          w = fitW;
          h = fitH;
        }
        final previewChild = ClipRRect(
          borderRadius: BorderRadius.circular(10),
          clipBehavior: Clip.antiAlias,
          child: ColoredBox(
            color: _previewStageUnderlay(displayPayload),
            child: SizedBox(
              width: w,
              height: h,
              child: DigitalMenuDisplayLayout(
                payload: displayPayload,
                onRequestClose: onClose,
              ),
            ),
          ),
        );

        final previewViewport = isPortraitPhone
            ? Center(
                child: RotatedBox(
                  quarterTurns: 1,
                  child: SizedBox(
                    width: w,
                    height: h,
                    child: previewChild,
                  ),
                ),
              )
            : Center(child: previewChild);

        final Widget staged = narrow
            ? InteractiveViewer(
                minScale: 0.35,
                maxScale: 4,
                boundaryMargin: const EdgeInsets.all(120),
                clipBehavior: Clip.hardEdge,
                child: SizedBox(
                  width: maxW,
                  height: maxH,
                  child: previewViewport,
                ),
              )
            : previewViewport;

        return ColoredBox(
          color: _previewStageMarginColor(displayPayload),
          child: Stack(
            fit: StackFit.expand,
            children: [
              staged,
              SafeArea(
                child: Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Material(
                      elevation: 4,
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.white,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: l10n.adminTvPreviewClose,
                            icon: const Icon(Icons.close_rounded),
                            onPressed: onClose,
                          ),
                          IconButton(
                            tooltip: l10n.adminTvSlideAppearanceTitle,
                            icon: const Icon(Icons.tune_rounded),
                            onPressed: onOpenSettings,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
