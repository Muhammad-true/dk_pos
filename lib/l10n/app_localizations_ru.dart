// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appTitle => 'Doner Kebab';

  @override
  String get loginTitle => 'Вход';

  @override
  String get loginSubtitle => 'Doner Kebab POS';

  @override
  String get loginFormIntro => 'Войдите в систему, чтобы пользоваться кассой.';

  @override
  String get fieldUsername => 'Логин';

  @override
  String get fieldPassword => 'Пароль';

  @override
  String get fieldUsernameError => 'Введите логин';

  @override
  String get fieldPasswordError => 'Введите пароль';

  @override
  String get actionSignIn => 'Войти';

  @override
  String get posTitle => 'Касса';

  @override
  String get adminTitle => 'Админ-панель';

  @override
  String get adminHomeHint =>
      'Управление контентом и справочниками — в следующих экранах.';

  @override
  String get adminNavOverview => 'Обзор';

  @override
  String get adminNavUsers => 'Пользователи';

  @override
  String get adminNavCatalog => 'Каталог';

  @override
  String get adminNavOrders => 'Заказы';

  @override
  String get adminNavSettings => 'Настройки';

  @override
  String get adminNavSettingsDrawerHint => 'Язык приложения и другие параметры';

  @override
  String get adminDrawerSectionNav => 'Разделы';

  @override
  String get adminDrawerSectionLanguage => 'Язык интерфейса';

  @override
  String get adminNavOverviewDrawerHint => 'Сводка и быстрые действия';

  @override
  String get adminNavUsersDrawerHint => 'Учётные записи и роли';

  @override
  String get adminNavCatalogDrawerHint => 'Категории и позиции меню';

  @override
  String get adminNavOrdersDrawerHint => 'Отчёт по продажам за период';

  @override
  String get adminDrawerSignOutHint => 'Понадобится снова войти в систему';

  @override
  String get adminUsersTitle => 'Пользователи';

  @override
  String get adminUsersEmpty => 'Пользователей пока нет';

  @override
  String get adminUsersAdd => 'Добавить';

  @override
  String get adminUsersEdit => 'Изменить';

  @override
  String get adminUsersDelete => 'Удалить';

  @override
  String get adminUsersColumnCreated => 'Создан';

  @override
  String get adminUsersActions => 'Действия';

  @override
  String adminUsersConfirmDelete(String name) {
    return 'Удалить пользователя «$name»? Это действие нельзя отменить.';
  }

  @override
  String get adminUsersPasswordOptional =>
      'Не менять пароль — оставьте поле пустым';

  @override
  String get adminUsersPasswordMin => 'Пароль не короче 6 символов';

  @override
  String get adminUsersLoadError => 'Не удалось загрузить список';

  @override
  String get fieldRole => 'Роль';

  @override
  String get actionCancel => 'Отмена';

  @override
  String get actionSave => 'Сохранить';

  @override
  String get adminDashboardHeadline => 'Рабочий стол';

  @override
  String get adminDashboardBody => 'Сводки и быстрые действия появятся здесь.';

  @override
  String get adminCatalogHint =>
      'Категории и позиции меню для POS и цифрового меню.';

  @override
  String get adminCatalogManageTitle => 'Категории меню';

  @override
  String get adminCatalogEmpty => 'Категорий пока нет';

  @override
  String get adminCatalogLoadError => 'Не удалось загрузить категории';

  @override
  String get adminCategoryAdd => 'Добавить категорию';

  @override
  String get adminCategoryFormTitle => 'Новая категория';

  @override
  String get adminCategoryNameRu => 'Название (русский)';

  @override
  String get adminCategoryNameTg => 'Название (тоҷикӣ)';

  @override
  String get adminCategoryNameEn => 'Название (English)';

  @override
  String get adminCategorySubtitleRu => 'Подзаголовок (русский), необязательно';

  @override
  String get adminCategorySubtitleTg => 'Подзаголовок (тоҷикӣ)';

  @override
  String get adminCategorySubtitleEn => 'Subtitle (English)';

  @override
  String get adminCategorySortOrder => 'Порядок в списке';

  @override
  String get adminCategorySortInvalid => 'Введите целое число';

  @override
  String get adminCategoryNameRuError => 'Введите название на русском';

  @override
  String get adminCategoryCreated => 'Категория создана';

  @override
  String get adminCategoryParentLabel => 'Родительская категория';

  @override
  String get adminCategoryParentRoot => 'Корень (верхний уровень)';

  @override
  String adminCategoryDepthLabel(int level) {
    return 'уровень $level';
  }

  @override
  String get posCatalogBack => 'Назад';

  @override
  String get posCatalogSections => 'Разделы';

  @override
  String get posCatalogNoSubcategories => 'Нет подкатегорий';

  @override
  String get posCatalogNoItemsHere => 'В этом разделе нет товаров';

  @override
  String get posCatalogPickCategory => 'Выберите раздел слева';

  @override
  String get adminCatalogTabCategories => 'Категории';

  @override
  String get adminCatalogTabProducts => 'Товары';

  @override
  String get adminCatalogTabScreens => 'Экраны ТВ';

  @override
  String get adminCatalogHubLead =>
      'Каждый раздел открывается отдельным экраном с плавной анимацией (fade + сдвиг).';

  @override
  String get adminCatalogHubCategoriesHint =>
      'Дерево категорий меню и подзаголовки';

  @override
  String get adminCatalogHubProductsHint =>
      'Позиции, цены, изображения и поля для ТВ';

  @override
  String get adminCatalogHubCombosHint => 'Комбо и состав наборов';

  @override
  String get adminCatalogHubScreensHint => 'Экраны ТВ1–ТВ4, превью и настройки';

  @override
  String get adminScreensTitle => 'Экраны цифрового меню';

  @override
  String get adminScreensHelpTitle => 'Как пользоваться';

  @override
  String get adminScreensHelpBody =>
      'ТВ2 (меню на экране в зале):\n1) Создайте экран — тип «ТВ2», сохраните.\n2) Нажмите «Просмотр ТВ», затем «Страницы и товары ТВ2» — добавьте страницы, заголовки колонок и товары из меню (слева герой, справа две колонки).\n3) В боковой панели превью задайте паузу между страницами и анимацию перехода, сохраните в экран.\n\nКарусель ТВ1: слайды берутся из поля tv1_page у товаров. Просмотр — черновой, как на ТВ.';

  @override
  String get adminScreensLoadError => 'Не удалось загрузить экраны';

  @override
  String get adminScreensEmpty => 'Экранов пока нет — создайте для приставки';

  @override
  String get adminScreenAdd => 'Добавить экран';

  @override
  String get adminScreenCreateTitle => 'Новый экран ТВ';

  @override
  String get adminScreenEditTitle => 'Редактировать экран';

  @override
  String get adminScreenDelete => 'Удалить экран';

  @override
  String adminScreenDeleteConfirm(String name) {
    return 'Удалить экран «$name»?';
  }

  @override
  String get adminScreenDeleted => 'Экран удалён';

  @override
  String get adminScreenName => 'Название (для списка)';

  @override
  String get adminScreenNameError => 'Введите название';

  @override
  String get adminScreenSlug => 'Slug (латиница, уникально)';

  @override
  String get adminScreenSlugError => 'Введите slug';

  @override
  String get adminScreenType => 'Шаблон показа';

  @override
  String get adminScreenTypeCarousel =>
      'Карусель меню (ТВ1, товары с tv1_page)';

  @override
  String get adminScreenTypeTv2 => 'ТВ2 — страницы из screen_pages';

  @override
  String get adminScreenTypeTv3 => 'ТВ3 — акции (promotions)';

  @override
  String get adminScreenTypeTv4 => 'ТВ4 — приветствие и оплата (config)';

  @override
  String get adminScreenActive => 'Активен';

  @override
  String get adminScreenInactive => 'выкл.';

  @override
  String get adminScreenDisplayTemplateTitle => 'Шаблон отображения';

  @override
  String get adminScreenDisplayTemplateSubtitle =>
      'Сетка и выравнивание для ТВ1/ТВ2 без JSON.';

  @override
  String get adminScreenColsAuto => 'Авто (по ширине экрана)';

  @override
  String get adminScreenTv1Columns => 'Колонок категорий (ТВ1)';

  @override
  String get adminScreenTv2Columns => 'Колонок списка (ТВ2)';

  @override
  String get adminScreenTv2ShowTemplate => 'Шаблон показа ТВ2';

  @override
  String get adminScreenTv2ShowTemplateClassic => 'Классический список';

  @override
  String get adminScreenTv2ShowTemplateVideoPromo =>
      'Видеофон + товар или комбо';

  @override
  String get adminScreenMaxCategoriesPerSlide =>
      'Макс. категорий на слайд (необязательно)';

  @override
  String get adminScreenMaxCategoriesHint =>
      'Пусто — по умолчанию, все категории на одном слайде.';

  @override
  String get adminScreenCenterGrid => 'Сетка по центру экрана';

  @override
  String get adminScreenCenterGridSubtitle =>
      'Выкл. — прижать сетку к левому краю.';

  @override
  String get adminScreenExtraConfigJson => 'Доп. JSON (необязательно)';

  @override
  String get adminScreenExtraConfigHint =>
      'Редкие ключи (напр. ТВ4). Поля конструктора перекрывают дубликаты здесь.';

  @override
  String get adminScreenTemplateNotForType =>
      'Настройки сетки только для карусели (ТВ1) и ТВ2. Для ТВ3/ТВ4 — при необходимости доп. JSON.';

  @override
  String get adminScreenConfigJson => 'Доп. JSON (необязательно)';

  @override
  String get adminScreenConfigInvalid => 'Некорректный JSON в конфиге';

  @override
  String get adminScreenCreated => 'Экран создан';

  @override
  String get adminScreenUpdated => 'Экран сохранён';

  @override
  String get adminScreenPreview => 'Просмотр';

  @override
  String get adminScreenPreviewTooltip => 'Как на ТВ (без сохранения формы)';

  @override
  String get adminTvPreviewTitle => 'Просмотр ТВ';

  @override
  String get adminTvPreviewBanner =>
      'Черновой просмотр. Для ТВ2 страницы берутся с сервера только у уже сохранённого экрана.';

  @override
  String get adminTvPreviewClose => 'Закрыть';

  @override
  String get adminTvPreviewError => 'Не удалось загрузить превью';

  @override
  String get adminTvPreviewRetry => 'Повторить';

  @override
  String get adminTv2OpenPagesEditor => 'Страницы и товары ТВ2…';

  @override
  String get adminTv3AppearanceTitle => 'ТВ3 — оформление';

  @override
  String get adminTv3HeaderTitleLabel => 'Заголовок (режим напитков)';

  @override
  String get adminTv3HeaderTitleHint =>
      'Пусто — красная полоса с текстом не показывается.';

  @override
  String get adminTv3PromoSloganLabel => 'Слоган над промо (карусель акций)';

  @override
  String get adminTv3PromoSloganHint =>
      'Пусто — строка над акцией не показывается (на уровне экрана). До 120 символов.';

  @override
  String get adminTv3PagePromoLineLabel => 'Своя строка над этим слайдом';

  @override
  String get adminTv3PagePromoLineHint =>
      'Пусто — как общий слоган экрана; свой текст — только над этим слайдом (до 120 символов).';

  @override
  String get adminTv3PromoSloganSave => 'Сохранить слоган';

  @override
  String get adminTv3PromoSloganSaved => 'Слоган сохранён';

  @override
  String get adminTv3LayoutLabel => 'Режим отображения';

  @override
  String get adminTv3LayoutPage3 => 'Сетка напитков (Page3)';

  @override
  String get adminTv3LayoutPromos => 'Карусель акций';

  @override
  String get adminTv3ContentHint =>
      'Категории и позиции берутся из меню ТВ1 (страница 3). Редактируйте экран карусели или меню в админке.';

  @override
  String get adminTv3PromoEditorTitle => 'ТВ3 — страницы акций';

  @override
  String get adminTv3PromoEditorSubtitle =>
      'Каждая страница — один слайд в режиме «Карусель акций»: один товар (герой) или комбо. Если для экрана есть страницы, они заменяют список акций из старой таблицы.';

  @override
  String get adminTv3PageTypePromoProduct => 'Один товар (слайд)';

  @override
  String get adminTv3PageTypePromoCombo => 'Комбо (слайд)';

  @override
  String get adminTv3PromoSelectCombo => 'Комбо';

  @override
  String get adminTv3PromoOpenCombosHint => 'Создайте комбо: Каталог → Комбо.';

  @override
  String get adminTv3PromoComboRequired =>
      'Выберите комбо перед добавлением страницы.';

  @override
  String get adminTv3PromoAddHero => 'Выбрать товар для слайда';

  @override
  String get adminTv3PromoHeroEmpty =>
      'Товар не выбран — слайд будет пустым, пока не добавите героя.';

  @override
  String get adminTv3PromoReorderHint =>
      'Порядок слайдов на ТВ: удерживайте значок ⋮⋮ слева у страницы и перетащите вверх или вниз.';

  @override
  String get adminTv3PromoOrderSaved => 'Порядок слайдов сохранён';

  @override
  String get adminTv3OpenPromoPagesEditor => 'Страницы акций (слайды)…';

  @override
  String get adminTv4OpenSlidesEditor => 'Слайды ТВ4 (приветствие и очередь)…';

  @override
  String get adminTv4SlideDurationLabel => 'Показ одного слайда ТВ4 (сек)';

  @override
  String get adminTv4SlidesEditorTitle => 'Слайды ТВ4';

  @override
  String get adminTv4SlidesEditorSubtitle =>
      'Страницы экрана: приветствие/оплата и очередь заказов чередуются на ТВ. Тексты и QR — в конфиге экрана.';

  @override
  String get adminTv4PageTypeWelcomePay => 'Приветствие и оплата';

  @override
  String get adminTv4PageTypeQueue => 'Очередь заказов';

  @override
  String get adminTv4PageAdded => 'Страница добавлена';

  @override
  String get adminTv4PageDeleted => 'Страница удалена';

  @override
  String get adminTv4SlidesReorderHint =>
      'Удерживайте ⋮⋮ и перетащите, чтобы изменить порядок слайдов.';

  @override
  String get adminTv4SlidesOrderSaved => 'Порядок слайдов сохранён';

  @override
  String get adminTv4AddPage => 'Добавить страницу';

  @override
  String get adminTv3PromoSlideThemeLabel => 'Цвета слайда';

  @override
  String get adminTv3PromoSlideThemeRedBg => 'Красный фон, белый текст';

  @override
  String get adminTv3PromoSlideThemeWhiteBg => 'Белый фон, красный текст';

  @override
  String get adminTv3PageTypePromoVideoBg => 'Полный экран: видео + текст';

  @override
  String get adminTv3PageTypePromoPhotoBg => 'Полный экран: фото + текст';

  @override
  String get adminTv3MediaBgTitle => 'Медиа на фон';

  @override
  String get adminTv3MediaBgHint =>
      'Загрузите файл и при необходимости заполните подписи поверх (режим «Карусель акций»).';

  @override
  String get adminTv3OverlayTitleLabel => 'Заголовок на экране';

  @override
  String get adminTv3OverlaySubtitleLabel => 'Подзаголовок';

  @override
  String get adminTv3OverlayPriceLabel => 'Цена / строка';

  @override
  String get adminTv3MediaPickVideo => 'Выбрать видео';

  @override
  String get adminTv3MediaPickPhoto => 'Выбрать фото';

  @override
  String get adminTv3MediaClear => 'Сбросить файл';

  @override
  String get adminCatalogTabCombos => 'Комбо';

  @override
  String get adminCombosTitle => 'Комбо';

  @override
  String get adminCombosEmpty => 'Комбо пока нет.';

  @override
  String get adminCombosCreateTitle => 'Новое комбо';

  @override
  String get adminCombosNameRu => 'Название (RU)';

  @override
  String get adminCombosPriceRu => 'Цена текстом (RU)';

  @override
  String get adminCombosCreated => 'Комбо создано';

  @override
  String get adminCombosLoadError => 'Не удалось загрузить комбо';

  @override
  String get adminCombosDescriptionRu => 'Описание для экрана (RU)';

  @override
  String get adminCombosUpdated => 'Комбо сохранено';

  @override
  String get adminCombosImageSection => 'Фото комбо';

  @override
  String get adminCombosRemoveImage => 'Убрать фото';

  @override
  String get adminCombosValidityTitle => 'Период действия (акция)';

  @override
  String get adminCombosDatesAny => 'Без ограничения по датам';

  @override
  String get adminCombosDatesRange => 'Только в интервале дат';

  @override
  String get adminCombosDateStart => 'С даты';

  @override
  String get adminCombosDateEnd => 'По дату';

  @override
  String get adminCombosTimesAny => 'Весь день (без ограничения по часам)';

  @override
  String get adminCombosTimesRange => 'Только в интервале часов каждый день';

  @override
  String get adminCombosTimeStart => 'С';

  @override
  String get adminCombosTimeEnd => 'По';

  @override
  String get adminCombosTimesBothRequired => 'Укажите время «С» и «По»';

  @override
  String get adminCombosValidityNow => 'Сейчас действует';

  @override
  String get adminCombosValidityOutside =>
      'Сейчас вне периода — на ТВ не показывается';

  @override
  String get adminCombosDeleteCombo => 'Удалить комбо';

  @override
  String adminCombosDeleteComboConfirm(String name) {
    return 'Удалить комбо «$name»? Если оно привязано к меню или экрану, сначала отвяжите.';
  }

  @override
  String get adminCombosDeleted => 'Комбо удалено';

  @override
  String get adminCombosDeleteErrorInUse =>
      'Нельзя удалить: комбо используется в меню или на экране';

  @override
  String get adminTv2EditorTitle => 'Страницы ТВ2';

  @override
  String get adminTv2EditorSubtitle =>
      'Экран ТВ2 создаётся без страниц. Добавьте страницу и выберите тип — откроются только нужные поля (разделённый экран, сетка list, фон с видео и т.д.).';

  @override
  String get adminTv2EditorPageAdded => 'Страница добавлена';

  @override
  String get adminTv2EditorTitlesSaved => 'Заголовки сохранены';

  @override
  String get adminTv2EditorItemAdded => 'Товар добавлен на страницу';

  @override
  String get adminTv2EditorItemRemoved => 'Товар убран со страницы';

  @override
  String get adminTv2EditorPickItem => 'Выберите товар из меню';

  @override
  String get adminTv2EditorPickHintMulti =>
      'Отметьте нужные позиции. Для роли «герой» можно выбрать только один товар.';

  @override
  String adminTv2EditorAddSelectedButton(int count) {
    return 'Добавить выбранные ($count)';
  }

  @override
  String adminTv2EditorItemsAddedBatch(int count) {
    return 'Добавлено позиций: $count';
  }

  @override
  String get adminTv2EditorSearch => 'Поиск по названию или id';

  @override
  String get adminTv2EditorNoPages => 'Страниц пока нет — добавьте первую.';

  @override
  String get adminTv2EditorReorderHint =>
      'Порядок страниц на ТВ2: удерживайте значок ⋮⋮ слева у строки и перетащите вверх или вниз.';

  @override
  String get adminTv2EditorOrderSaved => 'Порядок страниц сохранён';

  @override
  String get adminTv2EditorPageLabel => 'Страница';

  @override
  String get adminTv2EditorFirstColumn => 'Верхняя секция справа';

  @override
  String get adminTv2EditorSecondColumn => 'Нижняя секция справа';

  @override
  String get adminTv2EditorListTitleRu => 'Заголовок первой колонки (рус.)';

  @override
  String get adminTv2EditorSecondTitleRu => 'Заголовок второй колонки (рус.)';

  @override
  String get adminTv2EditorListGridTitleRu => 'Заголовок сетки (рус.)';

  @override
  String get adminTv2EditorPageHintSplit =>
      'Две колонки справа (как бургеры / напитки).';

  @override
  String get adminTv2EditorPageHintList =>
      'Сетка товаров и крупная карточка справа.';

  @override
  String get adminTv2EditorPageHintVideoBg =>
      'Видео на фоне, оффер и при необходимости полосы товаров.';

  @override
  String get adminTv2EditorVideoBgComboNoMenuItems =>
      'Режим «комбо»: состав задаётся в комбо, позиции из меню сюда не добавляются.';

  @override
  String get adminTv2EditorRoleHeroCardList => 'Карточка справа';

  @override
  String get adminTv2EditorRoleListGrid => 'В сетке';

  @override
  String get adminTv2EditorSaveTitles => 'Сохранить заголовки';

  @override
  String get adminTv2EditorItemsSection => 'Товары на странице';

  @override
  String get adminTv2EditorAddAsRole => 'Добавить как';

  @override
  String get adminTv2EditorAddFromMenu => 'Из меню';

  @override
  String get adminTv2EditorNoItemsOnPage =>
      'Пока нет позиций — добавьте из меню.';

  @override
  String get adminTv2EditorRoleHero => 'Герой (слева крупно)';

  @override
  String get adminTv2EditorRoleList => 'Первая колонка';

  @override
  String get adminTv2EditorRoleHotdog => 'Вторая колонка';

  @override
  String get adminTv2EditorLayoutPreview => 'Предпросмотр раскладки';

  @override
  String get adminTv2EditorLayoutTitlePlaceholder => 'Заголовок';

  @override
  String get adminTv2EditorLayoutHeroEmpty => 'Нет героя';

  @override
  String get adminTv2EditorLayoutListHint =>
      'Шаблон list — сетка карточек по всем позициям.';

  @override
  String adminTv2EditorLayoutMore(int count) {
    return '+$count ещё';
  }

  @override
  String get adminTv2UserGuideTitle => 'Как настроить меню на ТВ';

  @override
  String get adminTv2UserGuide1 =>
      '1. В списке экранов создайте экран: имя, латинский slug, тип «ТВ2» и сохраните.';

  @override
  String get adminTv2UserGuide2 =>
      '2. Пока страниц нет, просмотр пустой. Добавьте страницы в «Страницы и товары ТВ2» — настройки зависят от типа страницы.';

  @override
  String get adminTv2UserGuide3 =>
      '3. Для типа «Фон (видео)» настраиваются видео и оффер; для split — две колонки справа; для list — сетка и карточка.';

  @override
  String get adminTv2UserGuide4 =>
      '4. В превью в боковой панели задайте паузу между страницами и анимацию перехода, затем «Сохранить в экран».';

  @override
  String get adminTv2PagesTimingTitle => 'Смена страниц';

  @override
  String get adminTv2PagesTimingHint =>
      'Сколько секунд показывать каждую страницу и как плавно переключаться на следующую.';

  @override
  String get adminTv2PageTransitionLabel =>
      'Анимация перехода между страницами';

  @override
  String adminTv2PageHoldLabel(int seconds) {
    return 'Показ одной страницы: $seconds с';
  }

  @override
  String adminTv2TransitionDurationLabel(int ms) {
    return 'Длительность анимации: $ms мс';
  }

  @override
  String get adminTv2VariedTransitionsTitle =>
      'Чередовать переходы при видеофоне';

  @override
  String get adminTv2VariedTransitionsSubtitle =>
      'Если включено, при страницах с видео анимации сменяются по кругу (как раньше). Выключено — всегда выбранный выше тип.';

  @override
  String get adminTv2VideoOverlayTitle => 'Расположение текста на видео';

  @override
  String get adminTv2VideoOverlayHorizontal => 'По горизонтали';

  @override
  String get adminTv2VideoOverlayVertical => 'По вертикали';

  @override
  String get adminTv2AlignStart => 'Слева';

  @override
  String get adminTv2AlignCenter => 'По центру';

  @override
  String get adminTv2AlignEnd => 'Справа';

  @override
  String get adminTv2AlignBottom => 'Снизу';

  @override
  String get adminTv2AlignTop => 'Сверху';

  @override
  String get adminTv2AlignMiddle => 'По центру экрана';

  @override
  String get adminScreenTv2Pages => 'Страницы ТВ2';

  @override
  String get adminScreenTv2PagesHint =>
      'Тип и порядок страниц; наполнение настраивается отдельно.';

  @override
  String get adminScreenTv2SaveFirst =>
      'Сохраните экран с типом ТВ2, чтобы добавлять страницы.';

  @override
  String get adminScreenPageAdd => 'Добавить страницу';

  @override
  String get adminScreenPageTypeLabel => 'Тип новой страницы';

  @override
  String adminScreenPageItems(int count) {
    return 'Элементов: $count';
  }

  @override
  String get adminTv2PageTypeSplit => 'Разделённый экран (split)';

  @override
  String get adminTv2PageTypeDrinks => 'Напитки (drinks)';

  @override
  String get adminTv2PageTypeCarousel => 'Карусель (carousel)';

  @override
  String get adminTv2PageTypeList => 'Список (list)';

  @override
  String get adminTv2PageTypeVideoBg => 'Фон (видео)';

  @override
  String get adminTv2OptionalVideoTitle => 'Видео под макетом (опционально)';

  @override
  String get adminTv2OptionalVideoHint =>
      'Для split, list, drinks и carousel: ролик показывается за колонкой или сеткой, как на ТВ. Такие страницы можно чередовать со страницей «Фон (видео)» в одной ротации.';

  @override
  String get adminTv2OptionalVideoClear => 'Убрать видео';

  @override
  String get adminTv2OptionalPhotoTitle => 'Фото под макетом (опционально)';

  @override
  String get adminTv2OptionalPhotoHint =>
      'Статичная картинка на весь фон за колонкой или сеткой. Если задано и видео, и фото — на ТВ играет видео.';

  @override
  String get adminTv2OptionalPhotoClear => 'Убрать фото';

  @override
  String get adminTv2VideoBgPickPhoto => 'Выбрать изображение';

  @override
  String get adminTv2VideoBgClearPhoto => 'Убрать фото фона';

  @override
  String get adminTv2BackgroundFileEmpty => 'Файл не выбран';

  @override
  String get adminTv2VideoBgTitle => 'Видеофон';

  @override
  String get adminTv2VideoBgPickVideo => 'Выбрать видеофайл';

  @override
  String get adminTv2VideoBgNoVideo => 'Видео не выбрано';

  @override
  String get adminTv2VideoBgShowPhotos => 'Показывать фото блюд';

  @override
  String get adminTv2VideoBgModeMenu => 'Товар (из меню)';

  @override
  String get adminTv2VideoBgModeCombo => 'Комбо';

  @override
  String get adminTv2VideoBgSelectCombo => 'Выберите комбо';

  @override
  String get adminTv2VideoBgApplyCombo => 'Применить комбо';

  @override
  String get adminTv2VideoBgChooseHero => 'Выбрать товар из меню';

  @override
  String get adminTv2VideoBgContentSource => 'Контент поверх видео';

  @override
  String get adminTv2VideoBgWhatToShowProduct => 'Что показывать из товара';

  @override
  String get adminTv2VideoBgWhatToShowCombo => 'Что показывать из комбо';

  @override
  String get adminTv2VideoBgShowDescription => 'Описание';

  @override
  String get adminTv2VideoBgShowPrice => 'Цены';

  @override
  String get adminTv2VideoBgShowComboComposition => 'Состав (позиции)';

  @override
  String get adminTv2EditorVideoBgLayoutHint =>
      'На ТВ: видео на весь экран, снизу блок с названием и данными по выбранным пунктам (без дополнительных колонок).';

  @override
  String get adminTv2EditorVideoBgExtraHint =>
      'Доп. позиции под карточкой (как на экране)';

  @override
  String get adminScreenPageDeleteTitle => 'Удалить страницу';

  @override
  String adminScreenPageDeleteConfirm(String type) {
    return 'Удалить страницу «$type»?';
  }

  @override
  String get adminScreenPageAdded => 'Страница добавлена';

  @override
  String get adminScreenPageDeleted => 'Страница удалена';

  @override
  String get adminTvSlideAppearanceTitle => 'Оформление слайда';

  @override
  String get adminTvPresetLabel => 'Пресет';

  @override
  String get adminTvPresetCustom => 'Свой (текущий)';

  @override
  String get adminTvPresetDefault => 'По умолчанию';

  @override
  String get adminTvPresetCompact => 'Компакт';

  @override
  String get adminTvPresetBold => 'Акцент';

  @override
  String get adminTvTransition => 'Анимация карусели';

  @override
  String get adminTvTransitionFade => 'Затухание';

  @override
  String get adminTvTransitionSlide => 'Сдвиг';

  @override
  String get adminTvTransitionSlideUp => 'Снизу вверх (свайп страницы)';

  @override
  String get adminTvTransitionCrossFade => 'Перекрёстное затухание';

  @override
  String get adminTvTransitionNone => 'Без анимации';

  @override
  String get adminTvTransitionScale => 'Масштаб';

  @override
  String get adminTvCategorySubtitle => 'Подзаголовок категории';

  @override
  String get adminTvItemPrice => 'Цена позиции';

  @override
  String get adminTvItemDivider => 'Разделитель между позициями';

  @override
  String get adminTvItemDescription => 'Описание / состав позиции';

  @override
  String get adminTvSlotsTitle => 'Порядок блоков (карточка ТВ1)';

  @override
  String get adminTvSlotsHint =>
      'Перетащите: заголовок, подзаголовок, линия, позиции.';

  @override
  String get adminTv2ListAppearance => 'Строка списка ТВ2';

  @override
  String get adminTv2ItemImage => 'Миниатюра';

  @override
  String get adminTvDraftTitle => 'Черновик контента превью';

  @override
  String get adminTvDraftHint =>
      'Демо-категория для превью (можно сохранить в config экрана).';

  @override
  String get adminTvDraftApply => 'Применить демо-черновик';

  @override
  String get adminTvDraftReset => 'Сбросить к данным каталога';

  @override
  String get adminTvDraftSaveToConfig => 'Сохранить черновик в config экрана';

  @override
  String get adminTvDraftSavedToConfig => 'Черновик записан в config экрана';

  @override
  String get adminTvSlideSaveToScreen => 'Сохранить в экран';

  @override
  String get adminTvSlideSaving => 'Сохранение…';

  @override
  String get adminTvSlideSaved => 'Сохранено в экран';

  @override
  String get adminTvSlideSaveError => 'Не удалось сохранить';

  @override
  String get adminTvSlideNoScreenId =>
      'Сохранение доступно только для сохранённого экрана (откройте превью из списка экранов).';

  @override
  String get adminTvStyleTitle => 'Цвета и шрифт (ТВ1)';

  @override
  String get adminTvStyleHexHint => 'Формат #RRGGBB; пусто — из темы';

  @override
  String get adminTvStyleSlideBg => 'Фон слайда';

  @override
  String get adminTvStyleHeaderBg => 'Фон шапки';

  @override
  String get adminTvStyleHeaderText => 'Текст шапки';

  @override
  String get adminTvStyleCategoryTitle => 'Заголовок категории';

  @override
  String get adminTvStyleCategorySubtitle => 'Подзаголовок категории';

  @override
  String get adminTvStyleItemName => 'Название позиции';

  @override
  String get adminTvStyleItemDesc => 'Описание позиции';

  @override
  String get adminTvStyleItemPrice => 'Цена позиции';

  @override
  String get adminTvStyleDivider => 'Разделители';

  @override
  String get adminTvStyleFontScale => 'Масштаб шрифта';

  @override
  String get adminTvStyleReset => 'Сбросить цвета и масштаб';

  @override
  String get adminMenuItemsTitle => 'Товары меню';

  @override
  String get adminMenuItemsEmpty => 'Позиций пока нет';

  @override
  String get adminMenuItemsLoadError => 'Не удалось загрузить товары';

  @override
  String get adminMenuItemAdd => 'Добавить товар';

  @override
  String get adminMenuItemCreateTitle => 'Новый товар';

  @override
  String get adminMenuItemEditTitle => 'Редактировать товар';

  @override
  String get adminMenuItemDelete => 'Удалить товар';

  @override
  String adminMenuItemDeleteConfirm(String name) {
    return 'Удалить «$name»? Это действие нельзя отменить, если позиция не используется в заказах.';
  }

  @override
  String get adminMenuItemCreated => 'Товар создан';

  @override
  String get adminMenuItemUpdated => 'Товар сохранён';

  @override
  String get adminMenuItemDeleted => 'Товар удалён';

  @override
  String get adminMenuItemId => 'ID (латиница, без пробелов)';

  @override
  String get adminMenuItemIdHint => 'например burger-1';

  @override
  String get adminMenuItemIdError => 'Введите id';

  @override
  String get adminMenuItemCategory => 'Категория';

  @override
  String get adminMenuItemPrice => 'Цена (число)';

  @override
  String get adminMenuItemPriceInvalid => 'Введите корректную цену';

  @override
  String get adminMenuItemPriceTextRu => 'Цена для экрана (рус.)';

  @override
  String get adminMenuItemPriceTextRuError => 'Введите текст цены';

  @override
  String get adminMenuItemPriceTextTg => 'Цена (тоҷикӣ)';

  @override
  String get adminMenuItemPriceTextEn => 'Цена (English)';

  @override
  String get adminMenuItemSaleUnit => 'Единица измерения';

  @override
  String get adminMenuItemPickImage => 'Загрузить фото на сервер';

  @override
  String get adminMenuItemImageReadError =>
      'Не удалось прочитать файл изображения';

  @override
  String get adminMenuItemUnitsLoadError =>
      'Не удалось загрузить единицы измерения';

  @override
  String get adminMenuItemUnitsEmpty => 'Справочник единиц пуст — проверьте БД';

  @override
  String get adminMenuItemUnitRequired => 'Выберите единицу измерения';

  @override
  String get adminMenuItemImagePath => 'Путь к фото (uploads/…)';

  @override
  String get adminMenuItemSku => 'Артикул (SKU)';

  @override
  String get adminMenuItemBarcode => 'Штрихкод';

  @override
  String get adminMenuItemTrackStock => 'Учитывать на складе';

  @override
  String get adminMenuItemAvailable => 'Доступен для продажи';

  @override
  String get adminMenuItemDescriptionRu => 'Описание (рус.), необязательно';

  @override
  String get adminMenuItemCompositionRu => 'Состав (рус.), необязательно';

  @override
  String get adminMenuItemVolumeVariantsJson =>
      'Объёмы и цены для ТВ (JSON), необязательно';

  @override
  String get adminMenuItemVolumeVariantsHint =>
      'JSON-массив; у каждого элемента поля label (объём) и priceText (цена). Пусто — без вариантов.';

  @override
  String get adminMenuItemVolumeVariantsInvalid =>
      'Некорректный JSON: нужен массив объектов с полями label и priceText';

  @override
  String get actionDelete => 'Удалить';

  @override
  String get adminOrdersHint =>
      'Продажи: оплаты со статусом «принята» за выбранные даты.';

  @override
  String get adminReportsSalesTitle => 'Продажи';

  @override
  String get adminReportsSalesSubtitle =>
      'Только подтверждённые оплаты (касса / POS). Филиал по умолчанию — branch_1.';

  @override
  String get adminReportsDateFrom => 'С даты';

  @override
  String get adminReportsDateTo => 'По дату';

  @override
  String get adminReportsShow => 'Показать';

  @override
  String get adminReportsLoadError => 'Не удалось загрузить отчёт';

  @override
  String adminReportsPaymentsCount(int count) {
    return 'Оплат: $count';
  }

  @override
  String adminReportsTotal(String amount) {
    return 'Сумма: $amount';
  }

  @override
  String get adminReportsEmpty => 'Нет продаж за выбранный период';

  @override
  String get adminReportsByMethod => 'По способу оплаты';

  @override
  String get adminReportsByDay => 'По дням';

  @override
  String get adminReportsTable => 'Список оплат (до 500)';

  @override
  String get adminReportsColumnTime => 'Дата и время';

  @override
  String get adminReportsColumnOrder => 'Заказ №';

  @override
  String get adminReportsColumnMethod => 'Способ';

  @override
  String get adminReportsColumnAmount => 'Сумма';

  @override
  String get adminReportsColumnDay => 'День';

  @override
  String get adminReportsColumnCountShort => 'Оплат';

  @override
  String get adminReportsMethodCash => 'Наличные';

  @override
  String get adminReportsMethodCard => 'Карта';

  @override
  String get adminReportsMethodOnline => 'Онлайн';

  @override
  String get adminReportsMethodDs => 'ДС';

  @override
  String get adminReportsMethodOther => 'Другое';

  @override
  String get actionRefreshMenu => 'Обновить меню';

  @override
  String get actionExit => 'Выход';

  @override
  String get actionRetry => 'Повторить';

  @override
  String get menuEmpty => 'Нет позиций в меню';

  @override
  String get cartEmpty => 'Корзина пуста';

  @override
  String get cartOrder => 'Заказ';

  @override
  String get cartClear => 'Очистить';

  @override
  String get cartTotal => 'Итого';

  @override
  String get roleAdmin => 'Админ';

  @override
  String get roleWarehouse => 'Склад';

  @override
  String get roleCashier => 'Касса';

  @override
  String get roleExpeditor => 'Сборщик';

  @override
  String get roleWaiter => 'Официант';

  @override
  String get posWorkspaceSubtitleCashier =>
      'Кассовое рабочее место • быстрая сборка заказа';

  @override
  String get posWorkspaceSubtitleWaiter =>
      'Официант • заказы на стол (оплата на кассе)';

  @override
  String get posWaiterOrderTypesHint =>
      'С собой, на месте и доставка — всегда с выбором стола; оплата только на кассе.';

  @override
  String get posTablePickWaiterHint =>
      'Для официанта стол обязателен — без стола оформить нельзя.';

  @override
  String get posWaiterCannotPay =>
      'Официант не может принимать оплату — подойдите к кассе.';

  @override
  String get expeditorTitle => 'Сборка и выдача';

  @override
  String get expeditorSectionBundling => 'Собрать';

  @override
  String get expeditorSectionPickup => 'Выдача';

  @override
  String get expeditorBundlingEmpty => 'Нет заказов, ожидающих сборки';

  @override
  String get expeditorPickupEmpty => 'Никто не ждёт выдачу';

  @override
  String get expeditorTapToConfirm =>
      'Нажмите, проверить позиции и подтвердить';

  @override
  String get expeditorTapToHandOut => 'Нажмите для выдачи по номеру';

  @override
  String get expeditorDetailBundlingHint =>
      'Все кухни отметили готовность. Подтвердите — клиент увидит, что заказ готов.';

  @override
  String get expeditorDetailPickupHint =>
      'Проверьте номер заказа и выдайте гостю или официанту.';

  @override
  String get expeditorConfirmReady => 'Готово';

  @override
  String get expeditorHandOut => 'Выдать заказ';

  @override
  String get expeditorQueueAllEmpty => 'Очередь пуста';

  @override
  String expeditorItemsLine(int count) {
    return '$count поз.';
  }

  @override
  String get posOpenExpeditor => 'Сборка / выдача';

  @override
  String get posOrdersDialogTitle => 'Заказы';

  @override
  String get posOrdersTabActive => 'Активные';

  @override
  String posOrdersTileSummary(int bundling, int pickup) {
    return 'сб. $bundling · выд. $pickup';
  }

  @override
  String get posOrdersWorkspaceValueHint => 'Открыть список';

  @override
  String get posOrdersActiveEmpty => 'Активных заказов пока нет';

  @override
  String get tooltipAppMenu => 'Меню';

  @override
  String get languageRu => 'Русский';

  @override
  String get languageEn => 'English';

  @override
  String get languageTg => 'Тоҷикӣ';

  @override
  String get kitchenSectionCooking => 'Готовятся';

  @override
  String get kitchenSectionWaitingOthers => 'Ожидание других кухонь';

  @override
  String get kitchenEmptyCooking => 'Нет заказов в работе';

  @override
  String get kitchenEmptyWaiting => 'Нет заказов на ожидании';

  @override
  String get kitchenAccept => 'Принято';

  @override
  String get kitchenReady => 'Готово';

  @override
  String get kitchenWaitingHint => 'Ваша часть готова. Ожидайте другие кухни.';

  @override
  String kitchenOrderNumber(String number) {
    return 'Заказ $number';
  }

  @override
  String get queueBoardTitle => 'Очередь заказов';

  @override
  String get queueBoardSectionPreparing => 'Готовятся';

  @override
  String get queueBoardSectionReady => 'Готово к выдаче';

  @override
  String get queueBoardEmpty => 'Нет заказов в очереди';

  @override
  String get queueBoardTooltipOpen => 'Показ очереди';
}
