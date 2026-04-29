// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Tajik (`tg`).
class AppLocalizationsTg extends AppLocalizations {
  AppLocalizationsTg([String locale = 'tg']) : super(locale);

  @override
  String get appTitle => 'Doner Kebab';

  @override
  String get loginTitle => 'Воридшавӣ';

  @override
  String get loginSubtitle => 'Doner Kebab POS';

  @override
  String get loginFormIntro => 'Барои истифода аз касса ворид шавед.';

  @override
  String get fieldUsername => 'Логин';

  @override
  String get fieldPassword => 'Рамз';

  @override
  String get fieldUsernameError => 'Логинро ворид кунед';

  @override
  String get fieldPasswordError => 'Рамзро ворид кунед';

  @override
  String get actionSignIn => 'Ворид шудан';

  @override
  String get posTitle => 'Касса';

  @override
  String get adminTitle => 'Панели идоракунӣ';

  @override
  String get adminHomeHint =>
      'Идоракунии меню ва маълумот баъдтар илова мешавад.';

  @override
  String get adminNavOverview => 'Намои умумӣ';

  @override
  String get adminNavUsers => 'Корбарон';

  @override
  String get adminNavCatalog => 'Каталог';

  @override
  String get adminNavOrders => 'Фармоишҳо';

  @override
  String get adminNavSettings => 'Танзимот';

  @override
  String get adminNavSettingsDrawerHint => 'Забон ва дигар имконот';

  @override
  String get adminDrawerSectionNav => 'Бахшҳо';

  @override
  String get adminDrawerSectionLanguage => 'Забони интерфейс';

  @override
  String get adminNavOverviewDrawerHint => 'Хулоса ва амалҳои зуд';

  @override
  String get adminNavUsersDrawerHint => 'Ҳисобҳо ва нақшҳо';

  @override
  String get adminNavCatalogDrawerHint => 'Категорияҳо ва ҷойҳои меню';

  @override
  String get adminNavOrdersDrawerHint => 'Ҳисоботи фурӯш барои давра';

  @override
  String get adminDrawerSignOutHint => 'Бори дигар бояд ворид шавед';

  @override
  String get adminUsersTitle => 'Корбарон';

  @override
  String get adminUsersEmpty => 'Корбар нест';

  @override
  String get adminUsersAdd => 'Илова';

  @override
  String get adminUsersEdit => 'Тағйир';

  @override
  String get adminUsersDelete => 'Нест кардан';

  @override
  String get adminUsersColumnCreated => 'Эҷод шуд';

  @override
  String get adminUsersActions => 'Амалҳо';

  @override
  String adminUsersConfirmDelete(String name) {
    return 'Корбари «$name»-ро нест кунед? Бозгашт нест.';
  }

  @override
  String get adminUsersPasswordOptional =>
      'Барои нигоҳ доштани парол холӣ гузоред';

  @override
  String get adminUsersPasswordMin => 'Парол на камтар аз 6 аломат';

  @override
  String get adminUsersLoadError => 'Боргирӣ нашуд';

  @override
  String get fieldRole => 'Нақш';

  @override
  String get actionCancel => 'Бекор';

  @override
  String get actionSave => 'Захира';

  @override
  String get adminDashboardHeadline => 'Мизи кор';

  @override
  String get adminDashboardBody =>
      'Хулосаҳо ва амалҳои зуд инҷо намоиш дода мешаванд.';

  @override
  String get adminCatalogHint =>
      'Категорияҳо ва ҷойҳои меню барои POS ва менюи рақамӣ.';

  @override
  String get adminCatalogManageTitle => 'Категорияҳои меню';

  @override
  String get adminCatalogEmpty => 'Категория нест';

  @override
  String get adminCatalogLoadError => 'Боргирӣ нашуд';

  @override
  String get adminCategoryAdd => 'Иловаи категория';

  @override
  String get adminCategoryFormTitle => 'Категорияи нав';

  @override
  String get adminCategoryNameRu => 'Ном (русӣ)';

  @override
  String get adminCategoryNameTg => 'Ном (тоҷикӣ)';

  @override
  String get adminCategoryNameEn => 'Ном (англисӣ)';

  @override
  String get adminCategorySubtitleRu => 'Зерном (русӣ), ихтиёрӣ';

  @override
  String get adminCategorySubtitleTg => 'Зерном (тоҷикӣ)';

  @override
  String get adminCategorySubtitleEn => 'Зерном (англисӣ)';

  @override
  String get adminCategorySortOrder => 'Тартиб дар рӯйхат';

  @override
  String get adminCategorySortInvalid => 'Рақами бутун ворид кунед';

  @override
  String get adminCategoryNameRuError => 'Номи русиро ворид кунед';

  @override
  String get adminCategoryCreated => 'Категория эҷод шуд';

  @override
  String get adminCategoryParentLabel => 'Категорияи волид';

  @override
  String get adminCategoryParentRoot => 'Реша (сатҳи боло)';

  @override
  String adminCategoryDepthLabel(int level) {
    return 'сатҳ $level';
  }

  @override
  String get posCatalogBack => 'Бозгашт';

  @override
  String get posCatalogSections => 'Бахшҳо';

  @override
  String get posCatalogNoSubcategories => 'Зеркатегория нест';

  @override
  String get posCatalogNoItemsHere => 'Дар ин бахш ҷой нест';

  @override
  String get posCatalogPickCategory => 'Бахшро аз чап интихоб кунед';

  @override
  String get adminCatalogTabCategories => 'Категорияҳо';

  @override
  String get adminCatalogTabProducts => 'Молҳо';

  @override
  String get adminCatalogTabScreens => 'Экранҳои ТВ';

  @override
  String get adminCatalogHubLead =>
      'Ҳар бахш дар экрани алоҳида бо аниматсияи нарм кушода мешавад.';

  @override
  String get adminCatalogHubCategoriesHint =>
      'Дарахти категорияҳо ва зерсарлавҳаҳо';

  @override
  String get adminCatalogHubProductsHint =>
      'Молҳо, нархҳо, суратҳо ва майдонҳои ТВ';

  @override
  String get adminCatalogHubCombosHint => 'Комбоҳо ва таркиб';

  @override
  String get adminCatalogHubScreensHint =>
      'Экранҳои ТВ1–ТВ4, пешнамоиш ва танзимот';

  @override
  String get adminScreensTitle => 'Экранҳои менюи рақамӣ';

  @override
  String get adminScreensHelpTitle => 'Чӣ тавр истифода бурдан';

  @override
  String get adminScreensHelpBody =>
      'ТВ2 (меню дар толор):\n1) Экран бо намуди «ТВ2» эҷод кунед ва захира кунед.\n2) «Пешнамоиши ТВ» → «Саҳифаҳо ва молҳои ТВ2»: саҳифаҳо, сарлавҳаҳо, молҳо (герой чап, ду сутун рост).\n3) Дар панели пешнамоиш таваққуф ва аниматсияро танзим кунед, ба экран захира кунед.\n\nКарусели ТВ1: слайдҳо аз tv1_page. Пешнамоиш — намуна.';

  @override
  String get adminScreensLoadError => 'Бор нашуд';

  @override
  String get adminScreensEmpty => 'Экран нест';

  @override
  String get adminScreenAdd => 'Экран';

  @override
  String get adminScreenCreateTitle => 'Экрани нав';

  @override
  String get adminScreenEditTitle => 'Тағйир';

  @override
  String get adminScreenDelete => 'Нест';

  @override
  String adminScreenDeleteConfirm(String name) {
    return '«$name»-ро нест кунед?';
  }

  @override
  String get adminScreenDeleted => 'Нест шуд';

  @override
  String get adminScreenName => 'Ном';

  @override
  String get adminScreenNameError => 'Ном ворид кунед';

  @override
  String get adminScreenSlug => 'Slug';

  @override
  String get adminScreenSlugError => 'Slug ворид кунед';

  @override
  String get adminScreenType => 'Намуна';

  @override
  String get adminScreenTypeCarousel => 'Карусели меню (tv1_page)';

  @override
  String get adminScreenTypeTv2 => 'ТВ2 — саҳифаҳо';

  @override
  String get adminScreenTypeTv3 => 'ТВ3 — аксияҳо';

  @override
  String get adminScreenTypeTv4 => 'ТВ4 — хуш омедед';

  @override
  String get adminScreenActive => 'Фаъол';

  @override
  String get adminScreenInactive => 'оф';

  @override
  String get adminScreenDisplayTemplateTitle => 'Намунаи намоиш';

  @override
  String get adminScreenDisplayTemplateSubtitle => 'Торҳои ТВ1/ТВ2 бе JSON.';

  @override
  String get adminScreenColsAuto => 'Авто (аз паҳнои экран)';

  @override
  String get adminScreenTv1Columns => 'Сутунҳои категория (ТВ1)';

  @override
  String get adminScreenTv2Columns => 'Сутунҳои рӯйхат (ТВ2)';

  @override
  String get adminScreenTv2ShowTemplate => 'Намунаи намоиши ТВ2';

  @override
  String get adminScreenTv2ShowTemplateClassic => 'Рӯйхати классикӣ';

  @override
  String get adminScreenTv2ShowTemplateVideoPromo =>
      'Заминаи видео + мол ё комбо';

  @override
  String get adminScreenMaxCategoriesPerSlide =>
      'Ҳадди аксари категория дар слайд';

  @override
  String get adminScreenMaxCategoriesHint =>
      'Холӣ — пешфарз, ҳама дар як слайд.';

  @override
  String get adminScreenCenterGrid => 'Тор дар маркази экран';

  @override
  String get adminScreenCenterGridSubtitle => 'Хомӯш — тор ба чап.';

  @override
  String get adminScreenExtraConfigJson => 'JSON-и иловагӣ';

  @override
  String get adminScreenExtraConfigHint =>
      'Калидҳои камёб. Конструктор калидҳои такрориро инҷо иваз мекунад.';

  @override
  String get adminScreenTemplateNotForType =>
      'Танҳо барои карусел (ТВ1) ва ТВ2. ТВ3/ТВ4 — JSON-и иловагӣ.';

  @override
  String get adminScreenConfigJson => 'JSON-и иловагӣ';

  @override
  String get adminScreenConfigInvalid => 'JSON нодуруст';

  @override
  String get adminScreenCreated => 'Эҷод шуд';

  @override
  String get adminScreenUpdated => 'Захира шуд';

  @override
  String get adminScreenPreview => 'Пешнамоиш';

  @override
  String get adminScreenPreviewTooltip => 'Пурра — на экрани ТВ (намуна)';

  @override
  String get adminTvPreviewTitle => 'Пешнамоиши ТВ';

  @override
  String get adminTvPreviewBanner =>
      'Пешнамоиши намунавӣ. Барои ТВ2 саҳифаҳо танҳо барои экрани захирашуда.';

  @override
  String get adminTvPreviewClose => 'Пӯшидан';

  @override
  String get adminTvPreviewError => 'Бор нашуд';

  @override
  String get adminTvPreviewRetry => 'Такрор';

  @override
  String get adminTv2OpenPagesEditor => 'Саҳифаҳо ва молҳои ТВ2…';

  @override
  String get adminTv3AppearanceTitle => 'ТВ3 — намоиш';

  @override
  String get adminTv3HeaderTitleLabel => 'Сарлавҳа (намоиши нӯшокиҳо)';

  @override
  String get adminTv3HeaderTitleHint =>
      'Холӣ — навори сурх бо матн намоиш дода намешавад.';

  @override
  String get adminTv3PromoSloganLabel => 'Шиор болои промо (карусели аксияҳо)';

  @override
  String get adminTv3PromoSloganHint =>
      'Холӣ — сатр болои аксия намоиш дода намешавад (агар дар слайд набошад). То 120 аломат.';

  @override
  String get adminTv3PagePromoLineLabel => 'Сатри боло ин барои ҳамин слайд';

  @override
  String get adminTv3PagePromoLineHint =>
      'Холӣ — шиори умумии экран; барои ин слайд то 120 аломат.';

  @override
  String get adminTv3PromoSloganSave => 'Нигоҳ доштани шиор';

  @override
  String get adminTv3PromoSloganSaved => 'Шиор нигоҳ дошта шуд';

  @override
  String get adminTv3LayoutLabel => 'Реҷаи намоиш';

  @override
  String get adminTv3LayoutPage3 => 'Шабакаи нӯшокиҳо (Page3)';

  @override
  String get adminTv3LayoutPromos => 'Карусели аксияҳо';

  @override
  String get adminTv3ContentHint =>
      'Категорияҳо ва молҳо аз менюи ТВ1 (саҳифаи 3). Экрани карусел ё менюро дар админ тағйир диҳед.';

  @override
  String get adminTv3PromoEditorTitle => 'ТВ3 — саҳифаҳои аксия';

  @override
  String get adminTv3PromoEditorSubtitle =>
      'Ҳар саҳифа як слайд дар реҷаи «Карусели аксияҳо»: як мол (герой) ё комбо. Агар саҳифаҳо бошанд, онҳо рӯйхати аксияҳои аз ҷадвали кӯҳнаро иваз мекунанд.';

  @override
  String get adminTv3PageTypePromoProduct => 'Як мол (слайд)';

  @override
  String get adminTv3PageTypePromoCombo => 'Комбо (слайд)';

  @override
  String get adminTv3PromoSelectCombo => 'Комбо';

  @override
  String get adminTv3PromoOpenCombosHint => 'Комбо созед: Каталог → Комбо.';

  @override
  String get adminTv3PromoComboRequired =>
      'Пеш аз илова кардани саҳифа комбо интихоб кунед.';

  @override
  String get adminTv3PromoAddHero => 'Мол барои слайд интихоб кунед';

  @override
  String get adminTv3PromoHeroEmpty =>
      'Мол нест — интизор шавед, ки герой илова шавад.';

  @override
  String get adminTv3PromoReorderHint =>
      'Тартиби слайдҳо дар ТВ: нишонаи ⋮⋮-ро дар канори чап нигоҳ доред ва кашед.';

  @override
  String get adminTv3PromoOrderSaved => 'Тартиби слайдҳо нигоҳ дошта шуд';

  @override
  String get adminTv3OpenPromoPagesEditor => 'Саҳифаҳои аксия (слайдҳо)…';

  @override
  String get adminTv4OpenSlidesEditor => 'Слайдҳои ТВ4 (хуш омедед ва навбат)…';

  @override
  String get adminTv4SlideDurationLabel => 'Давомнокии як слайди ТВ4 (сония)';

  @override
  String get adminTv4SlidesEditorTitle => 'Слайдҳои ТВ4';

  @override
  String get adminTv4SlidesEditorSubtitle =>
      'Саҳифаҳои экран: хуш омедед/пардохт ва навбат якбар як дар ТВ. Матн ва QR дар конфиги экран.';

  @override
  String get adminTv4PageTypeWelcomePay => 'Хуш омедед ва пардохт';

  @override
  String get adminTv4PageTypeQueue => 'Навбати фармоишҳо';

  @override
  String get adminTv4PageAdded => 'Саҳифа илова шуд';

  @override
  String get adminTv4PageDeleted => 'Саҳифа нест шуд';

  @override
  String get adminTv4SlidesReorderHint =>
      '⋮⋮-ро нигоҳ доред ва кашед, то тартибро иваз кунед.';

  @override
  String get adminTv4SlidesOrderSaved => 'Тартиби слайдҳо нигоҳ дошта шуд';

  @override
  String get adminTv4AddPage => 'Иловаи саҳифа';

  @override
  String get adminTv3PromoSlideThemeLabel => 'Рангҳои слайд';

  @override
  String get adminTv3PromoSlideThemeRedBg => 'Заминаи сурх, матни сафед';

  @override
  String get adminTv3PromoSlideThemeWhiteBg => 'Заминаи сафед, матни сурх';

  @override
  String get adminTv3PageTypePromoVideoBg => 'Пурра: видео + матн';

  @override
  String get adminTv3PageTypePromoPhotoBg => 'Пурра: акс + матн';

  @override
  String get adminTv3MediaBgTitle => 'Медиаи замина';

  @override
  String get adminTv3MediaBgHint => 'Файл бор кунед ва дар лозим матнҳои боло.';

  @override
  String get adminTv3OverlayTitleLabel => 'Сарлавҳа';

  @override
  String get adminTv3OverlaySubtitleLabel => 'Зерсарлавҳа';

  @override
  String get adminTv3OverlayPriceLabel => 'Нарх / сатр';

  @override
  String get adminTv3MediaPickVideo => 'Интихоби видео';

  @override
  String get adminTv3MediaPickPhoto => 'Интихоби акс';

  @override
  String get adminTv3MediaClear => 'Файлро нест кунед';

  @override
  String get adminCatalogTabCombos => 'Комбоҳо';

  @override
  String get adminCombosTitle => 'Комбоҳо';

  @override
  String get adminCombosEmpty => 'Комбо нест.';

  @override
  String get adminCombosCreateTitle => 'Комбои нав';

  @override
  String get adminCombosNameRu => 'Ном (RU)';

  @override
  String get adminCombosPriceRu => 'Нарх матнӣ (RU)';

  @override
  String get adminCombosCreated => 'Комбо эҷод шуд';

  @override
  String get adminCombosLoadError => 'Бор кардани комбо муяссар нашуд';

  @override
  String get adminCombosDescriptionRu => 'Тавсиф барои экран (RU)';

  @override
  String get adminCombosUpdated => 'Комбо нигоҳ дошта шуд';

  @override
  String get adminCombosImageSection => 'Акси комбо';

  @override
  String get adminCombosRemoveImage => 'Аксро нест кардан';

  @override
  String get adminCombosValidityTitle => 'Мӯҳлати эътибор (аксия)';

  @override
  String get adminCombosDatesAny => 'Бе маҳдудият аз рӯзҳо';

  @override
  String get adminCombosDatesRange => 'Танҳо дар байни рӯзҳо';

  @override
  String get adminCombosDateStart => 'Аз рӯз';

  @override
  String get adminCombosDateEnd => 'То рӯз';

  @override
  String get adminCombosTimesAny => 'Ҳама рӯз (бе маҳдудият аз соат)';

  @override
  String get adminCombosTimesRange => 'Танҳо дар байни соатҳо ҳар рӯз';

  @override
  String get adminCombosTimeStart => 'Аз';

  @override
  String get adminCombosTimeEnd => 'То';

  @override
  String get adminCombosTimesBothRequired =>
      'Вақти «Аз» ва «То»-ро нишон диҳед';

  @override
  String get adminCombosValidityNow => 'Ҳозир эътибор дорад';

  @override
  String get adminCombosValidityOutside =>
      'Берун аз мӯҳлат — дар ТВ намоиш дода намешавад';

  @override
  String get adminCombosDeleteCombo => 'Комборо нест кардан';

  @override
  String adminCombosDeleteComboConfirm(String name) {
    return 'Комбо «$name»-ро нест кунед? Агар ба меню ё экран вобаста бошад, аввал ҷудо кунед.';
  }

  @override
  String get adminCombosDeleted => 'Комбо нест шуд';

  @override
  String get adminCombosDeleteErrorInUse =>
      'Нест кардан мумкин нест: дар меню ё экран истифода мешавад';

  @override
  String get adminTv2EditorTitle => 'Саҳифаҳои ТВ2';

  @override
  String get adminTv2EditorSubtitle =>
      'Экрани ТВ2 бе саҳифа эҷод мешавад. Саҳифа илова кунед ва намудро интихоб кунед — танҳо майдонҳои лозима намоиш дода мешаванд.';

  @override
  String get adminTv2EditorPageAdded => 'Саҳифа илова шуд';

  @override
  String get adminTv2EditorTitlesSaved => 'Сарлавҳаҳо захира шуданд';

  @override
  String get adminTv2EditorItemAdded => 'Мол ба саҳифа илова шуд';

  @override
  String get adminTv2EditorItemRemoved => 'Мол аз саҳифа хориҷ шуд';

  @override
  String get adminTv2EditorPickItem => 'Молро интихоб кунед';

  @override
  String get adminTv2EditorPickHintMulti =>
      'Чанд молро интихоб кунед. Барои «герой» танҳо як мол.';

  @override
  String adminTv2EditorAddSelectedButton(int count) {
    return 'Иловаи интихобшуда ($count)';
  }

  @override
  String adminTv2EditorItemsAddedBatch(int count) {
    return 'Илова шуд: $count';
  }

  @override
  String get adminTv2EditorSearch => 'Ҷустуҷӯ бо ном ё id';

  @override
  String get adminTv2EditorNoPages => 'Саҳифа нест — якумро илова кунед.';

  @override
  String get adminTv2EditorReorderHint =>
      'Тартиби саҳифаҳо дар ТВ2: нишонаи ⋮⋮-ро дар канори чап нигоҳ доред ва кашед.';

  @override
  String get adminTv2EditorOrderSaved => 'Тартиби саҳифаҳо нигоҳ дошта шуд';

  @override
  String get adminTv2EditorPageLabel => 'Саҳифа';

  @override
  String get adminTv2EditorFirstColumn => 'Қисми рости боло';

  @override
  String get adminTv2EditorSecondColumn => 'Қисми рости поён';

  @override
  String get adminTv2EditorListTitleRu => 'Сарлавҳаи сутуни якум (русӣ)';

  @override
  String get adminTv2EditorSecondTitleRu => 'Сарлавҳаи сутуни дуюм (русӣ)';

  @override
  String get adminTv2EditorListGridTitleRu => 'Сарлавҳаи торик (русӣ)';

  @override
  String get adminTv2EditorPageHintSplit =>
      'Ду сутун дар рост (бургер / нӯшокӣ).';

  @override
  String get adminTv2EditorPageHintList =>
      'Торики молҳо ва корт калон дар рост.';

  @override
  String get adminTv2EditorPageHintVideoBg =>
      'Видео дар замина, оффер ва дар зарурият лентаҳои мол.';

  @override
  String get adminTv2EditorVideoBgComboNoMenuItems =>
      'Реҷаи «комбо»: таркиб дар комбо; аз меню ин ҷо илова намешавад.';

  @override
  String get adminTv2EditorRoleHeroCardList => 'Корт дар рост';

  @override
  String get adminTv2EditorRoleListGrid => 'Дар торик';

  @override
  String get adminTv2EditorSaveTitles => 'Захираи сарлавҳаҳо';

  @override
  String get adminTv2EditorItemsSection => 'Молҳо дар саҳифа';

  @override
  String get adminTv2EditorAddAsRole => 'Илова ҳамчун';

  @override
  String get adminTv2EditorAddFromMenu => 'Аз меню';

  @override
  String get adminTv2EditorNoItemsOnPage => 'Мол нест — аз меню илова кунед.';

  @override
  String get adminTv2EditorRoleHero => 'Герой (чап калон)';

  @override
  String get adminTv2EditorRoleList => 'Сутуни якум';

  @override
  String get adminTv2EditorRoleHotdog => 'Сутуни дуюм';

  @override
  String get adminTv2EditorLayoutPreview => 'Пешнамоиши тарҳ';

  @override
  String get adminTv2EditorLayoutTitlePlaceholder => 'Сарлавҳа';

  @override
  String get adminTv2EditorLayoutHeroEmpty => 'Герой нест';

  @override
  String get adminTv2EditorLayoutListHint =>
      'Намунаи list — шабака аз ҳама ҷойҳо.';

  @override
  String adminTv2EditorLayoutMore(int count) {
    return '+$count';
  }

  @override
  String get adminTv2UserGuideTitle => 'Чӣ тавр менюро дар ТВ танзим кунем';

  @override
  String get adminTv2UserGuide1 =>
      '1. Экран эҷод кунед: ном, slug, намуд «ТВ2», захира кунед.';

  @override
  String get adminTv2UserGuide2 =>
      '2. Бе саҳифа пешнамоиш холӣ аст. Дар «Саҳифаҳо ва молҳои ТВ2» илова кунед — танзимот аз намуди саҳифа вобаста аст.';

  @override
  String get adminTv2UserGuide3 =>
      '3. «Замина (видео)»: видео ва оффер; split: ду сутун; list: торик ва корт.';

  @override
  String get adminTv2UserGuide4 =>
      '4. Дар панели пешнамоиш таваққуф ва гузаришро танзим кунед, «ба экран захира кунед».';

  @override
  String get adminTv2PagesTimingTitle => 'Ивази саҳифаҳо';

  @override
  String get adminTv2PagesTimingHint =>
      'Чанд сония ҳар саҳифа намоиш дода шавад ва чӣ гуна ба оянда гузарад.';

  @override
  String get adminTv2PageTransitionLabel => 'Аниматсияи гузариш';

  @override
  String adminTv2PageHoldLabel(int seconds) {
    return 'Намоиши як саҳифа: $seconds с';
  }

  @override
  String adminTv2TransitionDurationLabel(int ms) {
    return 'Давомнокии аниматсия: $ms мс';
  }

  @override
  String get adminTv2VariedTransitionsTitle =>
      'Гузаришҳои навбатӣ бо заминаи видео';

  @override
  String get adminTv2VariedTransitionsSubtitle =>
      'Вақте фаъол аст, саҳифаҳо бо видео аниматсияро иваз мекунанд. Хомӯш — ҳамеша интихобшуда.';

  @override
  String get adminTv2VideoOverlayTitle => 'Ҷойгиршавии матн дар видео';

  @override
  String get adminTv2VideoOverlayHorizontal => 'Уфуқӣ';

  @override
  String get adminTv2VideoOverlayVertical => 'Амудӣ';

  @override
  String get adminTv2AlignStart => 'Чап';

  @override
  String get adminTv2AlignCenter => 'Марказ';

  @override
  String get adminTv2AlignEnd => 'Рост';

  @override
  String get adminTv2AlignBottom => 'Поён';

  @override
  String get adminTv2AlignTop => 'Боло';

  @override
  String get adminTv2AlignMiddle => 'Маркази экран';

  @override
  String get adminScreenTv2Pages => 'Саҳифаҳои ТВ2';

  @override
  String get adminScreenTv2PagesHint => 'Намуна ва тартиб; муҳтаво алоҳида.';

  @override
  String get adminScreenTv2SaveFirst =>
      'Аввал экранро ҳамчун ТВ2 захира кунед.';

  @override
  String get adminScreenPageAdd => 'Саҳифа';

  @override
  String get adminScreenPageTypeLabel => 'Намунаи нав';

  @override
  String adminScreenPageItems(int count) {
    return 'Элементҳо: $count';
  }

  @override
  String get adminTv2PageTypeSplit => 'split';

  @override
  String get adminTv2PageTypeDrinks => 'drinks';

  @override
  String get adminTv2PageTypeCarousel => 'carousel';

  @override
  String get adminTv2PageTypeList => 'list';

  @override
  String get adminTv2PageTypeVideoBg => 'Заминаи видео';

  @override
  String get adminTv2OptionalVideoTitle => 'Видео зери макет (ихтиёрӣ)';

  @override
  String get adminTv2OptionalVideoHint =>
      'Барои split, list, drinks ва carousel: ролик дар пушти макет. Метавонед бо саҳифаи «заминаи видео» дар як гардиш ҷойгир кунед.';

  @override
  String get adminTv2OptionalVideoClear => 'Видеоро нест кунед';

  @override
  String get adminTv2OptionalPhotoTitle => 'Акс зери макет (ихтиёрӣ)';

  @override
  String get adminTv2OptionalPhotoHint =>
      'Акси пурраи замина. Агар ҳам видео ва ҳам акс бошад, ТВ видео нишон медиҳад.';

  @override
  String get adminTv2OptionalPhotoClear => 'Аксро нест кунед';

  @override
  String get adminTv2VideoBgPickPhoto => 'Интихоби акс';

  @override
  String get adminTv2VideoBgClearPhoto => 'Акси заминаро нест кунед';

  @override
  String get adminTv2BackgroundFileEmpty => 'Файл интихоб нашудааст';

  @override
  String get adminTv2VideoBgTitle => 'Видеофон';

  @override
  String get adminTv2VideoBgPickVideo => 'Интихоби файлҳои видео';

  @override
  String get adminTv2VideoBgNoVideo => 'Видео нест';

  @override
  String get adminTv2VideoBgShowPhotos => 'Нишон додани акси хӯрок';

  @override
  String get adminTv2VideoBgModeMenu => 'Мол аз меню';

  @override
  String get adminTv2VideoBgModeCombo => 'Комбо';

  @override
  String get adminTv2VideoBgSelectCombo => 'Комборо интихоб кунед';

  @override
  String get adminTv2VideoBgApplyCombo => 'Комборо татбиқ кунед';

  @override
  String get adminTv2VideoBgChooseHero => 'Моли менюро интихоб кунед';

  @override
  String get adminTv2VideoBgContentSource => 'Мундариҷа болои видео';

  @override
  String get adminTv2VideoBgWhatToShowProduct => 'Аз мол чиро нишон диҳем';

  @override
  String get adminTv2VideoBgWhatToShowCombo => 'Аз комбо чиро нишон диҳем';

  @override
  String get adminTv2VideoBgShowDescription => 'Тавсиф';

  @override
  String get adminTv2VideoBgShowPrice => 'Нархҳо';

  @override
  String get adminTv2VideoBgShowComboComposition => 'Таркиб (сатрҳо)';

  @override
  String get adminTv2EditorVideoBgLayoutHint =>
      'Дар ТВ: видео пур экран, поён блок бо ном ва маълумоти интихобшуда (бе сутунҳои иловагӣ).';

  @override
  String get adminTv2EditorVideoBgExtraHint =>
      'Молҳои иловагӣ зери корт (чуноне дар экран)';

  @override
  String get adminScreenPageDeleteTitle => 'Нести саҳифа';

  @override
  String adminScreenPageDeleteConfirm(String type) {
    return '«$type»-ро нест кунед?';
  }

  @override
  String get adminScreenPageAdded => 'Илова шуд';

  @override
  String get adminScreenPageDeleted => 'Нест шуд';

  @override
  String get adminTvSlideAppearanceTitle => 'Намоиши слайд';

  @override
  String get adminTvPresetLabel => 'Намуна';

  @override
  String get adminTvPresetCustom => 'Фардӣ (ҳозира)';

  @override
  String get adminTvPresetDefault => 'Пешфарз';

  @override
  String get adminTvPresetCompact => 'Фишурда';

  @override
  String get adminTvPresetBold => 'Ҷаззоб';

  @override
  String get adminTvTransition => 'Аниматсияи карусел';

  @override
  String get adminTvTransitionFade => 'Нестшавӣ';

  @override
  String get adminTvTransitionSlide => 'Ҷобаҷо';

  @override
  String get adminTvTransitionSlideUp => 'Аз поён ба боло (гузариши саҳифа)';

  @override
  String get adminTvTransitionCrossFade => 'Нестшавии чорчӯба';

  @override
  String get adminTvTransitionNone => 'Бе аниматсия';

  @override
  String get adminTvTransitionScale => 'Миқёс';

  @override
  String get adminTvCategorySubtitle => 'Зерунвон категория';

  @override
  String get adminTvItemPrice => 'Нархи ҷой';

  @override
  String get adminTvItemDivider => 'Ҷудокунанда байни ҷойҳо';

  @override
  String get adminTvItemDescription => 'Тавсиф / таркиб';

  @override
  String get adminTvSlotsTitle => 'Тартиби блокҳо (корт ТВ1)';

  @override
  String get adminTvSlotsHint => 'Кашолакунед: сарлавҳа, зерунвон, хат, ҷойҳо.';

  @override
  String get adminTv2ListAppearance => 'Сатри рӯйхати ТВ2';

  @override
  String get adminTv2ItemImage => 'Акси хурд';

  @override
  String get adminTvDraftTitle => 'Намунаи мундариҷа';

  @override
  String get adminTvDraftHint =>
      'Категорияи демо барои пешнамоиш (ихтиёрӣ дар config).';

  @override
  String get adminTvDraftApply => 'Гузоштани демо';

  @override
  String get adminTvDraftReset => 'Бозгашт ба каталог';

  @override
  String get adminTvDraftSaveToConfig => 'Захира дар config экран';

  @override
  String get adminTvDraftSavedToConfig => 'Дар config экран захира шуд';

  @override
  String get adminTvSlideSaveToScreen => 'Захира дар экран';

  @override
  String get adminTvSlideSaving => 'Захира…';

  @override
  String get adminTvSlideSaved => 'Захира шуд';

  @override
  String get adminTvSlideSaveError => 'Захира нашуд';

  @override
  String get adminTvSlideNoScreenId =>
      'Захира танҳо барои экрани захирашуда (аз рӯйхат кушоед).';

  @override
  String get adminTvStyleTitle => 'Рангҳо ва шрифт (ТВ1)';

  @override
  String get adminTvStyleHexHint => '#RRGGBB; холӣ — аз мавзӯъ';

  @override
  String get adminTvStyleSlideBg => 'Заминаи слайд';

  @override
  String get adminTvStyleHeaderBg => 'Заминаи сар';

  @override
  String get adminTvStyleHeaderText => 'Матни сар';

  @override
  String get adminTvStyleCategoryTitle => 'Сарлавҳаи категория';

  @override
  String get adminTvStyleCategorySubtitle => 'Зерунвони категория';

  @override
  String get adminTvStyleItemName => 'Номи ҷой';

  @override
  String get adminTvStyleItemDesc => 'Тавсифи ҷой';

  @override
  String get adminTvStyleItemPrice => 'Нархи ҷой';

  @override
  String get adminTvStyleDivider => 'Ҷудокунандаҳо';

  @override
  String get adminTvStyleFontScale => 'Миқёси шрифт';

  @override
  String get adminTvStyleReset => 'Бозсозии рангҳо';

  @override
  String get adminMenuItemsTitle => 'Ҷойҳои меню';

  @override
  String get adminMenuItemsEmpty => 'Ҳоло ҷой нест';

  @override
  String get adminMenuItemsLoadError => 'Боргирӣ нашуд';

  @override
  String get adminMenuItemAdd => 'Иловаи ҷой';

  @override
  String get adminMenuItemCreateTitle => 'Ҷойи нав';

  @override
  String get adminMenuItemEditTitle => 'Тағйири ҷой';

  @override
  String get adminMenuItemDelete => 'Нест кардан';

  @override
  String adminMenuItemDeleteConfirm(String name) {
    return '«$name»-ро нест кунед? Агар дар фармоиш истифода нашавад.';
  }

  @override
  String get adminMenuItemCreated => 'Эҷод шуд';

  @override
  String get adminMenuItemUpdated => 'Захира шуд';

  @override
  String get adminMenuItemDeleted => 'Нест шуд';

  @override
  String get adminMenuItemId => 'ID (латинӣ)';

  @override
  String get adminMenuItemIdHint => 'масалан burger-1';

  @override
  String get adminMenuItemIdError => 'ID ворид кунед';

  @override
  String get adminMenuItemCategory => 'Категория';

  @override
  String get adminMenuItemPrice => 'Нарх (рақам)';

  @override
  String get adminMenuItemPriceInvalid => 'Нархи дуруст';

  @override
  String get adminMenuItemPriceTextRu => 'Нарх барои экран (русӣ)';

  @override
  String get adminMenuItemPriceTextRuError => 'Матни нарх';

  @override
  String get adminMenuItemPriceTextTg => 'Нарх (тоҷикӣ)';

  @override
  String get adminMenuItemPriceTextEn => 'Нарх (англисӣ)';

  @override
  String get adminMenuItemSaleUnit => 'Воҳиди ченак';

  @override
  String get adminMenuItemPickImage => 'Бор кардани акс ба сервер';

  @override
  String get adminMenuItemImageReadError => 'Хондани файли акс муяссар нашуд';

  @override
  String get adminMenuItemUnitsLoadError => 'Воҳидҳои ченак бор нашуданд';

  @override
  String get adminMenuItemUnitsEmpty => 'Рӯйхати воҳидҳо холӣ аст';

  @override
  String get adminMenuItemUnitRequired => 'Воҳиди ченакро интихоб кунед';

  @override
  String get adminMenuItemImagePath => 'Роҳи акс (uploads/…)';

  @override
  String get adminMenuItemSku => 'Артикул';

  @override
  String get adminMenuItemBarcode => 'Штрихкод';

  @override
  String get adminMenuItemTrackStock => 'Ҳисоб дар анбор';

  @override
  String get adminMenuItemAvailable => 'Дастрас барои фурӯш';

  @override
  String get adminMenuItemDescriptionRu => 'Тавсиф (русӣ)';

  @override
  String get adminMenuItemCompositionRu => 'Таркиб (русӣ)';

  @override
  String get adminMenuItemVolumeVariantsJson =>
      'Ҳаҷм ва нарх барои ТВ (JSON), ихтиёрӣ';

  @override
  String get adminMenuItemVolumeVariantsHint =>
      'Массиви JSON; дар ҳар элемент label (ҳаҷм) ва priceText (нарх). Холӣ — бе вариантҳо.';

  @override
  String get adminMenuItemVolumeVariantsInvalid =>
      'JSON нодуруст: массиви объектҳо бо label ва priceText лозим аст';

  @override
  String get actionDelete => 'Нест';

  @override
  String get adminOrdersHint =>
      'Фурӯш: пардохтҳои қабулшуда барои санаҳои интихобшуда.';

  @override
  String get adminReportsSalesTitle => 'Фурӯш';

  @override
  String get adminReportsSalesSubtitle =>
      'Танҳо пардохтҳои тасдиқшуда. Филиали пешфарз: branch_1.';

  @override
  String get adminReportsDateFrom => 'Аз сана';

  @override
  String get adminReportsDateTo => 'То сана';

  @override
  String get adminReportsShow => 'Нишон додан';

  @override
  String get adminReportsLoadError => 'Бор кардани ҳисобот муяссар нашуд';

  @override
  String adminReportsPaymentsCount(int count) {
    return 'Пардохтҳо: $count';
  }

  @override
  String adminReportsTotal(String amount) {
    return 'Ҳамагӣ: $amount';
  }

  @override
  String get adminReportsEmpty => 'Барои ин давра фурӯш нест';

  @override
  String get adminReportsByMethod => 'Бо усули пардохт';

  @override
  String get adminReportsByDay => 'Ба рӯзҳо';

  @override
  String get adminReportsTable => 'Рӯйхати пардохтҳо (то 500)';

  @override
  String get adminReportsColumnTime => 'Вақт';

  @override
  String get adminReportsColumnOrder => 'Фармоиш №';

  @override
  String get adminReportsColumnMethod => 'Усул';

  @override
  String get adminReportsColumnAmount => 'Маблағ';

  @override
  String get adminReportsColumnDay => 'Рӯз';

  @override
  String get adminReportsColumnCountShort => 'Шумора';

  @override
  String get adminReportsMethodCash => 'Нақд';

  @override
  String get adminReportsMethodCard => 'Корт';

  @override
  String get adminReportsMethodOnline => 'Онлайн';

  @override
  String get adminReportsMethodDs => 'ДС';

  @override
  String get adminReportsMethodOther => 'Дигар';

  @override
  String get actionRefreshMenu => 'Навсозии меню';

  @override
  String get actionExit => 'Баромадан';

  @override
  String get actionRetry => 'Такрор кардан';

  @override
  String get menuEmpty => 'Дар меню чиз нест';

  @override
  String get cartEmpty => 'Сабад холӣ аст';

  @override
  String get cartOrder => 'Фармоиш';

  @override
  String get cartClear => 'Тоза кардан';

  @override
  String get cartTotal => 'Ҳамагӣ';

  @override
  String get roleAdmin => 'Мудир';

  @override
  String get roleWarehouse => 'Ошхона';

  @override
  String get roleCashier => 'Касса';

  @override
  String get roleExpeditor => 'Jamkunanda';

  @override
  String get roleWaiter => 'Офисиант';

  @override
  String get posWorkspaceSubtitleCashier =>
      'Ҷои кори касса • ҷамъоварии зуди фармоиш';

  @override
  String get posWorkspaceSubtitleWaiter =>
      'Офисиант • фармоишҳо ба стол (пардохт дар касса)';

  @override
  String get posWaiterOrderTypesHint =>
      'Барои гирифтан, дар ҷой ва расонидан — ҳамеша стол интихоб кунед; пардохт танҳо дар касса.';

  @override
  String get posTablePickWaiterHint => 'Барои офисиант стол ҳатмӣ аст.';

  @override
  String get posWaiterCannotPay =>
      'Офисиант наметавонад пардохт қабул кунад — ба касса равед.';

  @override
  String get expeditorTitle => 'Jam o vorisi va dodan';

  @override
  String get expeditorSectionBundling => 'Farakhro jam kuned';

  @override
  String get expeditorSectionPickup => 'Ba mehmon dihed';

  @override
  String get expeditorBundlingEmpty => 'Farakhhoi intizor nest';

  @override
  String get expeditorPickupEmpty => 'Kase intizori giriftan nest';

  @override
  String get expeditorTapToConfirm => 'Pakhsh kuned, sanjed va tasdiq kuned';

  @override
  String get expeditorTapToHandOut => 'Baroi dodan pakhsh kuned';

  @override
  String get expeditorDetailBundlingHint =>
      'Hamai oshkhonaho tayyor. Tasdiq kuned.';

  @override
  String get expeditorDetailPickupHint =>
      'Raqami farakhro sanjed va ba mehon yoftsiat dihed.';

  @override
  String get expeditorConfirmReady => 'Baroi mehmon tayyor';

  @override
  String get expeditorHandOut => 'Farakhro dodan';

  @override
  String get expeditorQueueAllEmpty => 'Navbat kholi ast';

  @override
  String expeditorItemsLine(int count) {
    return '$count poz.';
  }

  @override
  String get posOpenExpeditor => 'Jam o / dodan';

  @override
  String get posOrdersDialogTitle => 'Farakhho';

  @override
  String get posOrdersTabActive => 'Faol';

  @override
  String posOrdersTileSummary(int bundling, int pickup) {
    return 'jam $bundling · dod $pickup';
  }

  @override
  String get posOrdersWorkspaceValueHint => 'Kushodan';

  @override
  String get posOrdersActiveEmpty => 'Farakhhoi faol nest';

  @override
  String get tooltipAppMenu => 'Меню';

  @override
  String get languageRu => 'Русӣ';

  @override
  String get languageEn => 'Англисӣ';

  @override
  String get languageTg => 'Тоҷикӣ';

  @override
  String get kitchenSectionCooking => 'Омода мешавад';

  @override
  String get kitchenSectionWaitingOthers => 'Интизори дигар ошхонаҳо';

  @override
  String get kitchenEmptyCooking => 'Фарох дар кор нест';

  @override
  String get kitchenEmptyWaiting => 'Интизорӣ нест';

  @override
  String get kitchenAccept => 'Гирифта шуд';

  @override
  String get kitchenReady => 'Тайёр';

  @override
  String get kitchenWaitingHint =>
      'Қисми шумо тайёр аст. Интизори дигар ошхонаҳо.';

  @override
  String kitchenOrderNumber(String number) {
    return 'Фарох $number';
  }

  @override
  String get queueBoardTitle => 'Навбати фарохҳо';

  @override
  String get queueBoardSectionPreparing => 'Омода мешавад';

  @override
  String get queueBoardSectionReady => 'Барои гирифтан тайёр';

  @override
  String get queueBoardEmpty => 'Навбат холӣ аст';

  @override
  String get queueBoardTooltipOpen => 'Намоиши навбат';
}
