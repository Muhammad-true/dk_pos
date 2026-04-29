import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ru.dart';
import 'app_localizations_tg.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ru'),
    Locale('tg'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In ru, this message translates to:
  /// **'Doner Kebab'**
  String get appTitle;

  /// No description provided for @loginTitle.
  ///
  /// In ru, this message translates to:
  /// **'Вход'**
  String get loginTitle;

  /// No description provided for @loginSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Doner Kebab POS'**
  String get loginSubtitle;

  /// No description provided for @loginFormIntro.
  ///
  /// In ru, this message translates to:
  /// **'Войдите в систему, чтобы пользоваться кассой.'**
  String get loginFormIntro;

  /// No description provided for @fieldUsername.
  ///
  /// In ru, this message translates to:
  /// **'Логин'**
  String get fieldUsername;

  /// No description provided for @fieldPassword.
  ///
  /// In ru, this message translates to:
  /// **'Пароль'**
  String get fieldPassword;

  /// No description provided for @fieldUsernameError.
  ///
  /// In ru, this message translates to:
  /// **'Введите логин'**
  String get fieldUsernameError;

  /// No description provided for @fieldPasswordError.
  ///
  /// In ru, this message translates to:
  /// **'Введите пароль'**
  String get fieldPasswordError;

  /// No description provided for @actionSignIn.
  ///
  /// In ru, this message translates to:
  /// **'Войти'**
  String get actionSignIn;

  /// No description provided for @posTitle.
  ///
  /// In ru, this message translates to:
  /// **'Касса'**
  String get posTitle;

  /// No description provided for @adminTitle.
  ///
  /// In ru, this message translates to:
  /// **'Админ-панель'**
  String get adminTitle;

  /// No description provided for @adminHomeHint.
  ///
  /// In ru, this message translates to:
  /// **'Управление контентом и справочниками — в следующих экранах.'**
  String get adminHomeHint;

  /// No description provided for @adminNavOverview.
  ///
  /// In ru, this message translates to:
  /// **'Обзор'**
  String get adminNavOverview;

  /// No description provided for @adminNavUsers.
  ///
  /// In ru, this message translates to:
  /// **'Пользователи'**
  String get adminNavUsers;

  /// No description provided for @adminNavCatalog.
  ///
  /// In ru, this message translates to:
  /// **'Каталог'**
  String get adminNavCatalog;

  /// No description provided for @adminNavOrders.
  ///
  /// In ru, this message translates to:
  /// **'Заказы'**
  String get adminNavOrders;

  /// No description provided for @adminNavSettings.
  ///
  /// In ru, this message translates to:
  /// **'Настройки'**
  String get adminNavSettings;

  /// No description provided for @adminNavSettingsDrawerHint.
  ///
  /// In ru, this message translates to:
  /// **'Язык приложения и другие параметры'**
  String get adminNavSettingsDrawerHint;

  /// No description provided for @adminDrawerSectionNav.
  ///
  /// In ru, this message translates to:
  /// **'Разделы'**
  String get adminDrawerSectionNav;

  /// No description provided for @adminDrawerSectionLanguage.
  ///
  /// In ru, this message translates to:
  /// **'Язык интерфейса'**
  String get adminDrawerSectionLanguage;

  /// No description provided for @adminNavOverviewDrawerHint.
  ///
  /// In ru, this message translates to:
  /// **'Сводка и быстрые действия'**
  String get adminNavOverviewDrawerHint;

  /// No description provided for @adminNavUsersDrawerHint.
  ///
  /// In ru, this message translates to:
  /// **'Учётные записи и роли'**
  String get adminNavUsersDrawerHint;

  /// No description provided for @adminNavCatalogDrawerHint.
  ///
  /// In ru, this message translates to:
  /// **'Категории и позиции меню'**
  String get adminNavCatalogDrawerHint;

  /// No description provided for @adminNavOrdersDrawerHint.
  ///
  /// In ru, this message translates to:
  /// **'Отчёт по продажам за период'**
  String get adminNavOrdersDrawerHint;

  /// No description provided for @adminDrawerSignOutHint.
  ///
  /// In ru, this message translates to:
  /// **'Понадобится снова войти в систему'**
  String get adminDrawerSignOutHint;

  /// No description provided for @adminUsersTitle.
  ///
  /// In ru, this message translates to:
  /// **'Пользователи'**
  String get adminUsersTitle;

  /// No description provided for @adminUsersEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Пользователей пока нет'**
  String get adminUsersEmpty;

  /// No description provided for @adminUsersAdd.
  ///
  /// In ru, this message translates to:
  /// **'Добавить'**
  String get adminUsersAdd;

  /// No description provided for @adminUsersEdit.
  ///
  /// In ru, this message translates to:
  /// **'Изменить'**
  String get adminUsersEdit;

  /// No description provided for @adminUsersDelete.
  ///
  /// In ru, this message translates to:
  /// **'Удалить'**
  String get adminUsersDelete;

  /// No description provided for @adminUsersColumnCreated.
  ///
  /// In ru, this message translates to:
  /// **'Создан'**
  String get adminUsersColumnCreated;

  /// No description provided for @adminUsersActions.
  ///
  /// In ru, this message translates to:
  /// **'Действия'**
  String get adminUsersActions;

  /// No description provided for @adminUsersConfirmDelete.
  ///
  /// In ru, this message translates to:
  /// **'Удалить пользователя «{name}»? Это действие нельзя отменить.'**
  String adminUsersConfirmDelete(String name);

  /// No description provided for @adminUsersPasswordOptional.
  ///
  /// In ru, this message translates to:
  /// **'Не менять пароль — оставьте поле пустым'**
  String get adminUsersPasswordOptional;

  /// No description provided for @adminUsersPasswordMin.
  ///
  /// In ru, this message translates to:
  /// **'Пароль не короче 6 символов'**
  String get adminUsersPasswordMin;

  /// No description provided for @adminUsersLoadError.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось загрузить список'**
  String get adminUsersLoadError;

  /// No description provided for @fieldRole.
  ///
  /// In ru, this message translates to:
  /// **'Роль'**
  String get fieldRole;

  /// No description provided for @actionCancel.
  ///
  /// In ru, this message translates to:
  /// **'Отмена'**
  String get actionCancel;

  /// No description provided for @actionSave.
  ///
  /// In ru, this message translates to:
  /// **'Сохранить'**
  String get actionSave;

  /// No description provided for @adminDashboardHeadline.
  ///
  /// In ru, this message translates to:
  /// **'Рабочий стол'**
  String get adminDashboardHeadline;

  /// No description provided for @adminDashboardBody.
  ///
  /// In ru, this message translates to:
  /// **'Сводки и быстрые действия появятся здесь.'**
  String get adminDashboardBody;

  /// No description provided for @adminCatalogHint.
  ///
  /// In ru, this message translates to:
  /// **'Категории и позиции меню для POS и цифрового меню.'**
  String get adminCatalogHint;

  /// No description provided for @adminCatalogManageTitle.
  ///
  /// In ru, this message translates to:
  /// **'Категории меню'**
  String get adminCatalogManageTitle;

  /// No description provided for @adminCatalogEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Категорий пока нет'**
  String get adminCatalogEmpty;

  /// No description provided for @adminCatalogLoadError.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось загрузить категории'**
  String get adminCatalogLoadError;

  /// No description provided for @adminCategoryAdd.
  ///
  /// In ru, this message translates to:
  /// **'Добавить категорию'**
  String get adminCategoryAdd;

  /// No description provided for @adminCategoryFormTitle.
  ///
  /// In ru, this message translates to:
  /// **'Новая категория'**
  String get adminCategoryFormTitle;

  /// No description provided for @adminCategoryNameRu.
  ///
  /// In ru, this message translates to:
  /// **'Название (русский)'**
  String get adminCategoryNameRu;

  /// No description provided for @adminCategoryNameTg.
  ///
  /// In ru, this message translates to:
  /// **'Название (тоҷикӣ)'**
  String get adminCategoryNameTg;

  /// No description provided for @adminCategoryNameEn.
  ///
  /// In ru, this message translates to:
  /// **'Название (English)'**
  String get adminCategoryNameEn;

  /// No description provided for @adminCategorySubtitleRu.
  ///
  /// In ru, this message translates to:
  /// **'Подзаголовок (русский), необязательно'**
  String get adminCategorySubtitleRu;

  /// No description provided for @adminCategorySubtitleTg.
  ///
  /// In ru, this message translates to:
  /// **'Подзаголовок (тоҷикӣ)'**
  String get adminCategorySubtitleTg;

  /// No description provided for @adminCategorySubtitleEn.
  ///
  /// In ru, this message translates to:
  /// **'Subtitle (English)'**
  String get adminCategorySubtitleEn;

  /// No description provided for @adminCategorySortOrder.
  ///
  /// In ru, this message translates to:
  /// **'Порядок в списке'**
  String get adminCategorySortOrder;

  /// No description provided for @adminCategorySortInvalid.
  ///
  /// In ru, this message translates to:
  /// **'Введите целое число'**
  String get adminCategorySortInvalid;

  /// No description provided for @adminCategoryNameRuError.
  ///
  /// In ru, this message translates to:
  /// **'Введите название на русском'**
  String get adminCategoryNameRuError;

  /// No description provided for @adminCategoryCreated.
  ///
  /// In ru, this message translates to:
  /// **'Категория создана'**
  String get adminCategoryCreated;

  /// No description provided for @adminCategoryParentLabel.
  ///
  /// In ru, this message translates to:
  /// **'Родительская категория'**
  String get adminCategoryParentLabel;

  /// No description provided for @adminCategoryParentRoot.
  ///
  /// In ru, this message translates to:
  /// **'Корень (верхний уровень)'**
  String get adminCategoryParentRoot;

  /// No description provided for @adminCategoryDepthLabel.
  ///
  /// In ru, this message translates to:
  /// **'уровень {level}'**
  String adminCategoryDepthLabel(int level);

  /// No description provided for @posCatalogBack.
  ///
  /// In ru, this message translates to:
  /// **'Назад'**
  String get posCatalogBack;

  /// No description provided for @posCatalogSections.
  ///
  /// In ru, this message translates to:
  /// **'Разделы'**
  String get posCatalogSections;

  /// No description provided for @posCatalogNoSubcategories.
  ///
  /// In ru, this message translates to:
  /// **'Нет подкатегорий'**
  String get posCatalogNoSubcategories;

  /// No description provided for @posCatalogNoItemsHere.
  ///
  /// In ru, this message translates to:
  /// **'В этом разделе нет товаров'**
  String get posCatalogNoItemsHere;

  /// No description provided for @posCatalogPickCategory.
  ///
  /// In ru, this message translates to:
  /// **'Выберите раздел слева'**
  String get posCatalogPickCategory;

  /// No description provided for @adminCatalogTabCategories.
  ///
  /// In ru, this message translates to:
  /// **'Категории'**
  String get adminCatalogTabCategories;

  /// No description provided for @adminCatalogTabProducts.
  ///
  /// In ru, this message translates to:
  /// **'Товары'**
  String get adminCatalogTabProducts;

  /// No description provided for @adminCatalogTabScreens.
  ///
  /// In ru, this message translates to:
  /// **'Экраны ТВ'**
  String get adminCatalogTabScreens;

  /// No description provided for @adminCatalogHubLead.
  ///
  /// In ru, this message translates to:
  /// **'Каждый раздел открывается отдельным экраном с плавной анимацией (fade + сдвиг).'**
  String get adminCatalogHubLead;

  /// No description provided for @adminCatalogHubCategoriesHint.
  ///
  /// In ru, this message translates to:
  /// **'Дерево категорий меню и подзаголовки'**
  String get adminCatalogHubCategoriesHint;

  /// No description provided for @adminCatalogHubProductsHint.
  ///
  /// In ru, this message translates to:
  /// **'Позиции, цены, изображения и поля для ТВ'**
  String get adminCatalogHubProductsHint;

  /// No description provided for @adminCatalogHubCombosHint.
  ///
  /// In ru, this message translates to:
  /// **'Комбо и состав наборов'**
  String get adminCatalogHubCombosHint;

  /// No description provided for @adminCatalogHubScreensHint.
  ///
  /// In ru, this message translates to:
  /// **'Экраны ТВ1–ТВ4, превью и настройки'**
  String get adminCatalogHubScreensHint;

  /// No description provided for @adminScreensTitle.
  ///
  /// In ru, this message translates to:
  /// **'Экраны цифрового меню'**
  String get adminScreensTitle;

  /// No description provided for @adminScreensHelpTitle.
  ///
  /// In ru, this message translates to:
  /// **'Как пользоваться'**
  String get adminScreensHelpTitle;

  /// No description provided for @adminScreensHelpBody.
  ///
  /// In ru, this message translates to:
  /// **'ТВ2 (меню на экране в зале):\n1) Создайте экран — тип «ТВ2», сохраните.\n2) Нажмите «Просмотр ТВ», затем «Страницы и товары ТВ2» — добавьте страницы, заголовки колонок и товары из меню (слева герой, справа две колонки).\n3) В боковой панели превью задайте паузу между страницами и анимацию перехода, сохраните в экран.\n\nКарусель ТВ1: слайды берутся из поля tv1_page у товаров. Просмотр — черновой, как на ТВ.'**
  String get adminScreensHelpBody;

  /// No description provided for @adminScreensLoadError.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось загрузить экраны'**
  String get adminScreensLoadError;

  /// No description provided for @adminScreensEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Экранов пока нет — создайте для приставки'**
  String get adminScreensEmpty;

  /// No description provided for @adminScreenAdd.
  ///
  /// In ru, this message translates to:
  /// **'Добавить экран'**
  String get adminScreenAdd;

  /// No description provided for @adminScreenCreateTitle.
  ///
  /// In ru, this message translates to:
  /// **'Новый экран ТВ'**
  String get adminScreenCreateTitle;

  /// No description provided for @adminScreenEditTitle.
  ///
  /// In ru, this message translates to:
  /// **'Редактировать экран'**
  String get adminScreenEditTitle;

  /// No description provided for @adminScreenDelete.
  ///
  /// In ru, this message translates to:
  /// **'Удалить экран'**
  String get adminScreenDelete;

  /// No description provided for @adminScreenDeleteConfirm.
  ///
  /// In ru, this message translates to:
  /// **'Удалить экран «{name}»?'**
  String adminScreenDeleteConfirm(String name);

  /// No description provided for @adminScreenDeleted.
  ///
  /// In ru, this message translates to:
  /// **'Экран удалён'**
  String get adminScreenDeleted;

  /// No description provided for @adminScreenName.
  ///
  /// In ru, this message translates to:
  /// **'Название (для списка)'**
  String get adminScreenName;

  /// No description provided for @adminScreenNameError.
  ///
  /// In ru, this message translates to:
  /// **'Введите название'**
  String get adminScreenNameError;

  /// No description provided for @adminScreenSlug.
  ///
  /// In ru, this message translates to:
  /// **'Slug (латиница, уникально)'**
  String get adminScreenSlug;

  /// No description provided for @adminScreenSlugError.
  ///
  /// In ru, this message translates to:
  /// **'Введите slug'**
  String get adminScreenSlugError;

  /// No description provided for @adminScreenType.
  ///
  /// In ru, this message translates to:
  /// **'Шаблон показа'**
  String get adminScreenType;

  /// No description provided for @adminScreenTypeCarousel.
  ///
  /// In ru, this message translates to:
  /// **'Карусель меню (ТВ1, товары с tv1_page)'**
  String get adminScreenTypeCarousel;

  /// No description provided for @adminScreenTypeTv2.
  ///
  /// In ru, this message translates to:
  /// **'ТВ2 — страницы из screen_pages'**
  String get adminScreenTypeTv2;

  /// No description provided for @adminScreenTypeTv3.
  ///
  /// In ru, this message translates to:
  /// **'ТВ3 — акции (promotions)'**
  String get adminScreenTypeTv3;

  /// No description provided for @adminScreenTypeTv4.
  ///
  /// In ru, this message translates to:
  /// **'ТВ4 — приветствие и оплата (config)'**
  String get adminScreenTypeTv4;

  /// No description provided for @adminScreenActive.
  ///
  /// In ru, this message translates to:
  /// **'Активен'**
  String get adminScreenActive;

  /// No description provided for @adminScreenInactive.
  ///
  /// In ru, this message translates to:
  /// **'выкл.'**
  String get adminScreenInactive;

  /// No description provided for @adminScreenDisplayTemplateTitle.
  ///
  /// In ru, this message translates to:
  /// **'Шаблон отображения'**
  String get adminScreenDisplayTemplateTitle;

  /// No description provided for @adminScreenDisplayTemplateSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Сетка и выравнивание для ТВ1/ТВ2 без JSON.'**
  String get adminScreenDisplayTemplateSubtitle;

  /// No description provided for @adminScreenColsAuto.
  ///
  /// In ru, this message translates to:
  /// **'Авто (по ширине экрана)'**
  String get adminScreenColsAuto;

  /// No description provided for @adminScreenTv1Columns.
  ///
  /// In ru, this message translates to:
  /// **'Колонок категорий (ТВ1)'**
  String get adminScreenTv1Columns;

  /// No description provided for @adminScreenTv2Columns.
  ///
  /// In ru, this message translates to:
  /// **'Колонок списка (ТВ2)'**
  String get adminScreenTv2Columns;

  /// No description provided for @adminScreenTv2ShowTemplate.
  ///
  /// In ru, this message translates to:
  /// **'Шаблон показа ТВ2'**
  String get adminScreenTv2ShowTemplate;

  /// No description provided for @adminScreenTv2ShowTemplateClassic.
  ///
  /// In ru, this message translates to:
  /// **'Классический список'**
  String get adminScreenTv2ShowTemplateClassic;

  /// No description provided for @adminScreenTv2ShowTemplateVideoPromo.
  ///
  /// In ru, this message translates to:
  /// **'Видеофон + товар или комбо'**
  String get adminScreenTv2ShowTemplateVideoPromo;

  /// No description provided for @adminScreenMaxCategoriesPerSlide.
  ///
  /// In ru, this message translates to:
  /// **'Макс. категорий на слайд (необязательно)'**
  String get adminScreenMaxCategoriesPerSlide;

  /// No description provided for @adminScreenMaxCategoriesHint.
  ///
  /// In ru, this message translates to:
  /// **'Пусто — по умолчанию, все категории на одном слайде.'**
  String get adminScreenMaxCategoriesHint;

  /// No description provided for @adminScreenCenterGrid.
  ///
  /// In ru, this message translates to:
  /// **'Сетка по центру экрана'**
  String get adminScreenCenterGrid;

  /// No description provided for @adminScreenCenterGridSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Выкл. — прижать сетку к левому краю.'**
  String get adminScreenCenterGridSubtitle;

  /// No description provided for @adminScreenExtraConfigJson.
  ///
  /// In ru, this message translates to:
  /// **'Доп. JSON (необязательно)'**
  String get adminScreenExtraConfigJson;

  /// No description provided for @adminScreenExtraConfigHint.
  ///
  /// In ru, this message translates to:
  /// **'Редкие ключи (напр. ТВ4). Поля конструктора перекрывают дубликаты здесь.'**
  String get adminScreenExtraConfigHint;

  /// No description provided for @adminScreenTemplateNotForType.
  ///
  /// In ru, this message translates to:
  /// **'Настройки сетки только для карусели (ТВ1) и ТВ2. Для ТВ3/ТВ4 — при необходимости доп. JSON.'**
  String get adminScreenTemplateNotForType;

  /// No description provided for @adminScreenConfigJson.
  ///
  /// In ru, this message translates to:
  /// **'Доп. JSON (необязательно)'**
  String get adminScreenConfigJson;

  /// No description provided for @adminScreenConfigInvalid.
  ///
  /// In ru, this message translates to:
  /// **'Некорректный JSON в конфиге'**
  String get adminScreenConfigInvalid;

  /// No description provided for @adminScreenCreated.
  ///
  /// In ru, this message translates to:
  /// **'Экран создан'**
  String get adminScreenCreated;

  /// No description provided for @adminScreenUpdated.
  ///
  /// In ru, this message translates to:
  /// **'Экран сохранён'**
  String get adminScreenUpdated;

  /// No description provided for @adminScreenPreview.
  ///
  /// In ru, this message translates to:
  /// **'Просмотр'**
  String get adminScreenPreview;

  /// No description provided for @adminScreenPreviewTooltip.
  ///
  /// In ru, this message translates to:
  /// **'Как на ТВ (без сохранения формы)'**
  String get adminScreenPreviewTooltip;

  /// No description provided for @adminTvPreviewTitle.
  ///
  /// In ru, this message translates to:
  /// **'Просмотр ТВ'**
  String get adminTvPreviewTitle;

  /// No description provided for @adminTvPreviewBanner.
  ///
  /// In ru, this message translates to:
  /// **'Черновой просмотр. Для ТВ2 страницы берутся с сервера только у уже сохранённого экрана.'**
  String get adminTvPreviewBanner;

  /// No description provided for @adminTvPreviewClose.
  ///
  /// In ru, this message translates to:
  /// **'Закрыть'**
  String get adminTvPreviewClose;

  /// No description provided for @adminTvPreviewError.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось загрузить превью'**
  String get adminTvPreviewError;

  /// No description provided for @adminTvPreviewRetry.
  ///
  /// In ru, this message translates to:
  /// **'Повторить'**
  String get adminTvPreviewRetry;

  /// No description provided for @adminTv2OpenPagesEditor.
  ///
  /// In ru, this message translates to:
  /// **'Страницы и товары ТВ2…'**
  String get adminTv2OpenPagesEditor;

  /// No description provided for @adminTv3AppearanceTitle.
  ///
  /// In ru, this message translates to:
  /// **'ТВ3 — оформление'**
  String get adminTv3AppearanceTitle;

  /// No description provided for @adminTv3HeaderTitleLabel.
  ///
  /// In ru, this message translates to:
  /// **'Заголовок (режим напитков)'**
  String get adminTv3HeaderTitleLabel;

  /// No description provided for @adminTv3HeaderTitleHint.
  ///
  /// In ru, this message translates to:
  /// **'Пусто — красная полоса с текстом не показывается.'**
  String get adminTv3HeaderTitleHint;

  /// No description provided for @adminTv3PromoSloganLabel.
  ///
  /// In ru, this message translates to:
  /// **'Слоган над промо (карусель акций)'**
  String get adminTv3PromoSloganLabel;

  /// No description provided for @adminTv3PromoSloganHint.
  ///
  /// In ru, this message translates to:
  /// **'Пусто — строка над акцией не показывается (на уровне экрана). До 120 символов.'**
  String get adminTv3PromoSloganHint;

  /// No description provided for @adminTv3PagePromoLineLabel.
  ///
  /// In ru, this message translates to:
  /// **'Своя строка над этим слайдом'**
  String get adminTv3PagePromoLineLabel;

  /// No description provided for @adminTv3PagePromoLineHint.
  ///
  /// In ru, this message translates to:
  /// **'Пусто — как общий слоган экрана; свой текст — только над этим слайдом (до 120 символов).'**
  String get adminTv3PagePromoLineHint;

  /// No description provided for @adminTv3PromoSloganSave.
  ///
  /// In ru, this message translates to:
  /// **'Сохранить слоган'**
  String get adminTv3PromoSloganSave;

  /// No description provided for @adminTv3PromoSloganSaved.
  ///
  /// In ru, this message translates to:
  /// **'Слоган сохранён'**
  String get adminTv3PromoSloganSaved;

  /// No description provided for @adminTv3LayoutLabel.
  ///
  /// In ru, this message translates to:
  /// **'Режим отображения'**
  String get adminTv3LayoutLabel;

  /// No description provided for @adminTv3LayoutPage3.
  ///
  /// In ru, this message translates to:
  /// **'Сетка напитков (Page3)'**
  String get adminTv3LayoutPage3;

  /// No description provided for @adminTv3LayoutPromos.
  ///
  /// In ru, this message translates to:
  /// **'Карусель акций'**
  String get adminTv3LayoutPromos;

  /// No description provided for @adminTv3ContentHint.
  ///
  /// In ru, this message translates to:
  /// **'Категории и позиции берутся из меню ТВ1 (страница 3). Редактируйте экран карусели или меню в админке.'**
  String get adminTv3ContentHint;

  /// No description provided for @adminTv3PromoEditorTitle.
  ///
  /// In ru, this message translates to:
  /// **'ТВ3 — страницы акций'**
  String get adminTv3PromoEditorTitle;

  /// No description provided for @adminTv3PromoEditorSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Каждая страница — один слайд в режиме «Карусель акций»: один товар (герой) или комбо. Если для экрана есть страницы, они заменяют список акций из старой таблицы.'**
  String get adminTv3PromoEditorSubtitle;

  /// No description provided for @adminTv3PageTypePromoProduct.
  ///
  /// In ru, this message translates to:
  /// **'Один товар (слайд)'**
  String get adminTv3PageTypePromoProduct;

  /// No description provided for @adminTv3PageTypePromoCombo.
  ///
  /// In ru, this message translates to:
  /// **'Комбо (слайд)'**
  String get adminTv3PageTypePromoCombo;

  /// No description provided for @adminTv3PromoSelectCombo.
  ///
  /// In ru, this message translates to:
  /// **'Комбо'**
  String get adminTv3PromoSelectCombo;

  /// No description provided for @adminTv3PromoOpenCombosHint.
  ///
  /// In ru, this message translates to:
  /// **'Создайте комбо: Каталог → Комбо.'**
  String get adminTv3PromoOpenCombosHint;

  /// No description provided for @adminTv3PromoComboRequired.
  ///
  /// In ru, this message translates to:
  /// **'Выберите комбо перед добавлением страницы.'**
  String get adminTv3PromoComboRequired;

  /// No description provided for @adminTv3PromoAddHero.
  ///
  /// In ru, this message translates to:
  /// **'Выбрать товар для слайда'**
  String get adminTv3PromoAddHero;

  /// No description provided for @adminTv3PromoHeroEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Товар не выбран — слайд будет пустым, пока не добавите героя.'**
  String get adminTv3PromoHeroEmpty;

  /// No description provided for @adminTv3PromoReorderHint.
  ///
  /// In ru, this message translates to:
  /// **'Порядок слайдов на ТВ: удерживайте значок ⋮⋮ слева у страницы и перетащите вверх или вниз.'**
  String get adminTv3PromoReorderHint;

  /// No description provided for @adminTv3PromoOrderSaved.
  ///
  /// In ru, this message translates to:
  /// **'Порядок слайдов сохранён'**
  String get adminTv3PromoOrderSaved;

  /// No description provided for @adminTv3OpenPromoPagesEditor.
  ///
  /// In ru, this message translates to:
  /// **'Страницы акций (слайды)…'**
  String get adminTv3OpenPromoPagesEditor;

  /// No description provided for @adminTv4OpenSlidesEditor.
  ///
  /// In ru, this message translates to:
  /// **'Слайды ТВ4 (приветствие и очередь)…'**
  String get adminTv4OpenSlidesEditor;

  /// No description provided for @adminTv4SlideDurationLabel.
  ///
  /// In ru, this message translates to:
  /// **'Показ одного слайда ТВ4 (сек)'**
  String get adminTv4SlideDurationLabel;

  /// No description provided for @adminTv4SlidesEditorTitle.
  ///
  /// In ru, this message translates to:
  /// **'Слайды ТВ4'**
  String get adminTv4SlidesEditorTitle;

  /// No description provided for @adminTv4SlidesEditorSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Страницы экрана: приветствие/оплата и очередь заказов чередуются на ТВ. Тексты и QR — в конфиге экрана.'**
  String get adminTv4SlidesEditorSubtitle;

  /// No description provided for @adminTv4PageTypeWelcomePay.
  ///
  /// In ru, this message translates to:
  /// **'Приветствие и оплата'**
  String get adminTv4PageTypeWelcomePay;

  /// No description provided for @adminTv4PageTypeQueue.
  ///
  /// In ru, this message translates to:
  /// **'Очередь заказов'**
  String get adminTv4PageTypeQueue;

  /// No description provided for @adminTv4PageAdded.
  ///
  /// In ru, this message translates to:
  /// **'Страница добавлена'**
  String get adminTv4PageAdded;

  /// No description provided for @adminTv4PageDeleted.
  ///
  /// In ru, this message translates to:
  /// **'Страница удалена'**
  String get adminTv4PageDeleted;

  /// No description provided for @adminTv4SlidesReorderHint.
  ///
  /// In ru, this message translates to:
  /// **'Удерживайте ⋮⋮ и перетащите, чтобы изменить порядок слайдов.'**
  String get adminTv4SlidesReorderHint;

  /// No description provided for @adminTv4SlidesOrderSaved.
  ///
  /// In ru, this message translates to:
  /// **'Порядок слайдов сохранён'**
  String get adminTv4SlidesOrderSaved;

  /// No description provided for @adminTv4AddPage.
  ///
  /// In ru, this message translates to:
  /// **'Добавить страницу'**
  String get adminTv4AddPage;

  /// No description provided for @adminTv3PromoSlideThemeLabel.
  ///
  /// In ru, this message translates to:
  /// **'Цвета слайда'**
  String get adminTv3PromoSlideThemeLabel;

  /// No description provided for @adminTv3PromoSlideThemeRedBg.
  ///
  /// In ru, this message translates to:
  /// **'Красный фон, белый текст'**
  String get adminTv3PromoSlideThemeRedBg;

  /// No description provided for @adminTv3PromoSlideThemeWhiteBg.
  ///
  /// In ru, this message translates to:
  /// **'Белый фон, красный текст'**
  String get adminTv3PromoSlideThemeWhiteBg;

  /// No description provided for @adminTv3PageTypePromoVideoBg.
  ///
  /// In ru, this message translates to:
  /// **'Полный экран: видео + текст'**
  String get adminTv3PageTypePromoVideoBg;

  /// No description provided for @adminTv3PageTypePromoPhotoBg.
  ///
  /// In ru, this message translates to:
  /// **'Полный экран: фото + текст'**
  String get adminTv3PageTypePromoPhotoBg;

  /// No description provided for @adminTv3MediaBgTitle.
  ///
  /// In ru, this message translates to:
  /// **'Медиа на фон'**
  String get adminTv3MediaBgTitle;

  /// No description provided for @adminTv3MediaBgHint.
  ///
  /// In ru, this message translates to:
  /// **'Загрузите файл и при необходимости заполните подписи поверх (режим «Карусель акций»).'**
  String get adminTv3MediaBgHint;

  /// No description provided for @adminTv3OverlayTitleLabel.
  ///
  /// In ru, this message translates to:
  /// **'Заголовок на экране'**
  String get adminTv3OverlayTitleLabel;

  /// No description provided for @adminTv3OverlaySubtitleLabel.
  ///
  /// In ru, this message translates to:
  /// **'Подзаголовок'**
  String get adminTv3OverlaySubtitleLabel;

  /// No description provided for @adminTv3OverlayPriceLabel.
  ///
  /// In ru, this message translates to:
  /// **'Цена / строка'**
  String get adminTv3OverlayPriceLabel;

  /// No description provided for @adminTv3MediaPickVideo.
  ///
  /// In ru, this message translates to:
  /// **'Выбрать видео'**
  String get adminTv3MediaPickVideo;

  /// No description provided for @adminTv3MediaPickPhoto.
  ///
  /// In ru, this message translates to:
  /// **'Выбрать фото'**
  String get adminTv3MediaPickPhoto;

  /// No description provided for @adminTv3MediaClear.
  ///
  /// In ru, this message translates to:
  /// **'Сбросить файл'**
  String get adminTv3MediaClear;

  /// No description provided for @adminCatalogTabCombos.
  ///
  /// In ru, this message translates to:
  /// **'Комбо'**
  String get adminCatalogTabCombos;

  /// No description provided for @adminCombosTitle.
  ///
  /// In ru, this message translates to:
  /// **'Комбо'**
  String get adminCombosTitle;

  /// No description provided for @adminCombosEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Комбо пока нет.'**
  String get adminCombosEmpty;

  /// No description provided for @adminCombosCreateTitle.
  ///
  /// In ru, this message translates to:
  /// **'Новое комбо'**
  String get adminCombosCreateTitle;

  /// No description provided for @adminCombosNameRu.
  ///
  /// In ru, this message translates to:
  /// **'Название (RU)'**
  String get adminCombosNameRu;

  /// No description provided for @adminCombosPriceRu.
  ///
  /// In ru, this message translates to:
  /// **'Цена текстом (RU)'**
  String get adminCombosPriceRu;

  /// No description provided for @adminCombosCreated.
  ///
  /// In ru, this message translates to:
  /// **'Комбо создано'**
  String get adminCombosCreated;

  /// No description provided for @adminCombosLoadError.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось загрузить комбо'**
  String get adminCombosLoadError;

  /// No description provided for @adminCombosDescriptionRu.
  ///
  /// In ru, this message translates to:
  /// **'Описание для экрана (RU)'**
  String get adminCombosDescriptionRu;

  /// No description provided for @adminCombosUpdated.
  ///
  /// In ru, this message translates to:
  /// **'Комбо сохранено'**
  String get adminCombosUpdated;

  /// No description provided for @adminCombosImageSection.
  ///
  /// In ru, this message translates to:
  /// **'Фото комбо'**
  String get adminCombosImageSection;

  /// No description provided for @adminCombosRemoveImage.
  ///
  /// In ru, this message translates to:
  /// **'Убрать фото'**
  String get adminCombosRemoveImage;

  /// No description provided for @adminCombosValidityTitle.
  ///
  /// In ru, this message translates to:
  /// **'Период действия (акция)'**
  String get adminCombosValidityTitle;

  /// No description provided for @adminCombosDatesAny.
  ///
  /// In ru, this message translates to:
  /// **'Без ограничения по датам'**
  String get adminCombosDatesAny;

  /// No description provided for @adminCombosDatesRange.
  ///
  /// In ru, this message translates to:
  /// **'Только в интервале дат'**
  String get adminCombosDatesRange;

  /// No description provided for @adminCombosDateStart.
  ///
  /// In ru, this message translates to:
  /// **'С даты'**
  String get adminCombosDateStart;

  /// No description provided for @adminCombosDateEnd.
  ///
  /// In ru, this message translates to:
  /// **'По дату'**
  String get adminCombosDateEnd;

  /// No description provided for @adminCombosTimesAny.
  ///
  /// In ru, this message translates to:
  /// **'Весь день (без ограничения по часам)'**
  String get adminCombosTimesAny;

  /// No description provided for @adminCombosTimesRange.
  ///
  /// In ru, this message translates to:
  /// **'Только в интервале часов каждый день'**
  String get adminCombosTimesRange;

  /// No description provided for @adminCombosTimeStart.
  ///
  /// In ru, this message translates to:
  /// **'С'**
  String get adminCombosTimeStart;

  /// No description provided for @adminCombosTimeEnd.
  ///
  /// In ru, this message translates to:
  /// **'По'**
  String get adminCombosTimeEnd;

  /// No description provided for @adminCombosTimesBothRequired.
  ///
  /// In ru, this message translates to:
  /// **'Укажите время «С» и «По»'**
  String get adminCombosTimesBothRequired;

  /// No description provided for @adminCombosValidityNow.
  ///
  /// In ru, this message translates to:
  /// **'Сейчас действует'**
  String get adminCombosValidityNow;

  /// No description provided for @adminCombosValidityOutside.
  ///
  /// In ru, this message translates to:
  /// **'Сейчас вне периода — на ТВ не показывается'**
  String get adminCombosValidityOutside;

  /// No description provided for @adminCombosDeleteCombo.
  ///
  /// In ru, this message translates to:
  /// **'Удалить комбо'**
  String get adminCombosDeleteCombo;

  /// No description provided for @adminCombosDeleteComboConfirm.
  ///
  /// In ru, this message translates to:
  /// **'Удалить комбо «{name}»? Если оно привязано к меню или экрану, сначала отвяжите.'**
  String adminCombosDeleteComboConfirm(String name);

  /// No description provided for @adminCombosDeleted.
  ///
  /// In ru, this message translates to:
  /// **'Комбо удалено'**
  String get adminCombosDeleted;

  /// No description provided for @adminCombosDeleteErrorInUse.
  ///
  /// In ru, this message translates to:
  /// **'Нельзя удалить: комбо используется в меню или на экране'**
  String get adminCombosDeleteErrorInUse;

  /// No description provided for @adminTv2EditorTitle.
  ///
  /// In ru, this message translates to:
  /// **'Страницы ТВ2'**
  String get adminTv2EditorTitle;

  /// No description provided for @adminTv2EditorSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Экран ТВ2 создаётся без страниц. Добавьте страницу и выберите тип — откроются только нужные поля (разделённый экран, сетка list, фон с видео и т.д.).'**
  String get adminTv2EditorSubtitle;

  /// No description provided for @adminTv2EditorPageAdded.
  ///
  /// In ru, this message translates to:
  /// **'Страница добавлена'**
  String get adminTv2EditorPageAdded;

  /// No description provided for @adminTv2EditorTitlesSaved.
  ///
  /// In ru, this message translates to:
  /// **'Заголовки сохранены'**
  String get adminTv2EditorTitlesSaved;

  /// No description provided for @adminTv2EditorItemAdded.
  ///
  /// In ru, this message translates to:
  /// **'Товар добавлен на страницу'**
  String get adminTv2EditorItemAdded;

  /// No description provided for @adminTv2EditorItemRemoved.
  ///
  /// In ru, this message translates to:
  /// **'Товар убран со страницы'**
  String get adminTv2EditorItemRemoved;

  /// No description provided for @adminTv2EditorPickItem.
  ///
  /// In ru, this message translates to:
  /// **'Выберите товар из меню'**
  String get adminTv2EditorPickItem;

  /// No description provided for @adminTv2EditorPickHintMulti.
  ///
  /// In ru, this message translates to:
  /// **'Отметьте нужные позиции. Для роли «герой» можно выбрать только один товар.'**
  String get adminTv2EditorPickHintMulti;

  /// No description provided for @adminTv2EditorAddSelectedButton.
  ///
  /// In ru, this message translates to:
  /// **'Добавить выбранные ({count})'**
  String adminTv2EditorAddSelectedButton(int count);

  /// No description provided for @adminTv2EditorItemsAddedBatch.
  ///
  /// In ru, this message translates to:
  /// **'Добавлено позиций: {count}'**
  String adminTv2EditorItemsAddedBatch(int count);

  /// No description provided for @adminTv2EditorSearch.
  ///
  /// In ru, this message translates to:
  /// **'Поиск по названию или id'**
  String get adminTv2EditorSearch;

  /// No description provided for @adminTv2EditorNoPages.
  ///
  /// In ru, this message translates to:
  /// **'Страниц пока нет — добавьте первую.'**
  String get adminTv2EditorNoPages;

  /// No description provided for @adminTv2EditorReorderHint.
  ///
  /// In ru, this message translates to:
  /// **'Порядок страниц на ТВ2: удерживайте значок ⋮⋮ слева у строки и перетащите вверх или вниз.'**
  String get adminTv2EditorReorderHint;

  /// No description provided for @adminTv2EditorOrderSaved.
  ///
  /// In ru, this message translates to:
  /// **'Порядок страниц сохранён'**
  String get adminTv2EditorOrderSaved;

  /// No description provided for @adminTv2EditorPageLabel.
  ///
  /// In ru, this message translates to:
  /// **'Страница'**
  String get adminTv2EditorPageLabel;

  /// No description provided for @adminTv2EditorFirstColumn.
  ///
  /// In ru, this message translates to:
  /// **'Верхняя секция справа'**
  String get adminTv2EditorFirstColumn;

  /// No description provided for @adminTv2EditorSecondColumn.
  ///
  /// In ru, this message translates to:
  /// **'Нижняя секция справа'**
  String get adminTv2EditorSecondColumn;

  /// No description provided for @adminTv2EditorListTitleRu.
  ///
  /// In ru, this message translates to:
  /// **'Заголовок первой колонки (рус.)'**
  String get adminTv2EditorListTitleRu;

  /// No description provided for @adminTv2EditorSecondTitleRu.
  ///
  /// In ru, this message translates to:
  /// **'Заголовок второй колонки (рус.)'**
  String get adminTv2EditorSecondTitleRu;

  /// No description provided for @adminTv2EditorListGridTitleRu.
  ///
  /// In ru, this message translates to:
  /// **'Заголовок сетки (рус.)'**
  String get adminTv2EditorListGridTitleRu;

  /// No description provided for @adminTv2EditorPageHintSplit.
  ///
  /// In ru, this message translates to:
  /// **'Две колонки справа (как бургеры / напитки).'**
  String get adminTv2EditorPageHintSplit;

  /// No description provided for @adminTv2EditorPageHintList.
  ///
  /// In ru, this message translates to:
  /// **'Сетка товаров и крупная карточка справа.'**
  String get adminTv2EditorPageHintList;

  /// No description provided for @adminTv2EditorPageHintVideoBg.
  ///
  /// In ru, this message translates to:
  /// **'Видео на фоне, оффер и при необходимости полосы товаров.'**
  String get adminTv2EditorPageHintVideoBg;

  /// No description provided for @adminTv2EditorVideoBgComboNoMenuItems.
  ///
  /// In ru, this message translates to:
  /// **'Режим «комбо»: состав задаётся в комбо, позиции из меню сюда не добавляются.'**
  String get adminTv2EditorVideoBgComboNoMenuItems;

  /// No description provided for @adminTv2EditorRoleHeroCardList.
  ///
  /// In ru, this message translates to:
  /// **'Карточка справа'**
  String get adminTv2EditorRoleHeroCardList;

  /// No description provided for @adminTv2EditorRoleListGrid.
  ///
  /// In ru, this message translates to:
  /// **'В сетке'**
  String get adminTv2EditorRoleListGrid;

  /// No description provided for @adminTv2EditorSaveTitles.
  ///
  /// In ru, this message translates to:
  /// **'Сохранить заголовки'**
  String get adminTv2EditorSaveTitles;

  /// No description provided for @adminTv2EditorItemsSection.
  ///
  /// In ru, this message translates to:
  /// **'Товары на странице'**
  String get adminTv2EditorItemsSection;

  /// No description provided for @adminTv2EditorAddAsRole.
  ///
  /// In ru, this message translates to:
  /// **'Добавить как'**
  String get adminTv2EditorAddAsRole;

  /// No description provided for @adminTv2EditorAddFromMenu.
  ///
  /// In ru, this message translates to:
  /// **'Из меню'**
  String get adminTv2EditorAddFromMenu;

  /// No description provided for @adminTv2EditorNoItemsOnPage.
  ///
  /// In ru, this message translates to:
  /// **'Пока нет позиций — добавьте из меню.'**
  String get adminTv2EditorNoItemsOnPage;

  /// No description provided for @adminTv2EditorRoleHero.
  ///
  /// In ru, this message translates to:
  /// **'Герой (слева крупно)'**
  String get adminTv2EditorRoleHero;

  /// No description provided for @adminTv2EditorRoleList.
  ///
  /// In ru, this message translates to:
  /// **'Первая колонка'**
  String get adminTv2EditorRoleList;

  /// No description provided for @adminTv2EditorRoleHotdog.
  ///
  /// In ru, this message translates to:
  /// **'Вторая колонка'**
  String get adminTv2EditorRoleHotdog;

  /// No description provided for @adminTv2EditorLayoutPreview.
  ///
  /// In ru, this message translates to:
  /// **'Предпросмотр раскладки'**
  String get adminTv2EditorLayoutPreview;

  /// No description provided for @adminTv2EditorLayoutTitlePlaceholder.
  ///
  /// In ru, this message translates to:
  /// **'Заголовок'**
  String get adminTv2EditorLayoutTitlePlaceholder;

  /// No description provided for @adminTv2EditorLayoutHeroEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Нет героя'**
  String get adminTv2EditorLayoutHeroEmpty;

  /// No description provided for @adminTv2EditorLayoutListHint.
  ///
  /// In ru, this message translates to:
  /// **'Шаблон list — сетка карточек по всем позициям.'**
  String get adminTv2EditorLayoutListHint;

  /// No description provided for @adminTv2EditorLayoutMore.
  ///
  /// In ru, this message translates to:
  /// **'+{count} ещё'**
  String adminTv2EditorLayoutMore(int count);

  /// No description provided for @adminTv2UserGuideTitle.
  ///
  /// In ru, this message translates to:
  /// **'Как настроить меню на ТВ'**
  String get adminTv2UserGuideTitle;

  /// No description provided for @adminTv2UserGuide1.
  ///
  /// In ru, this message translates to:
  /// **'1. В списке экранов создайте экран: имя, латинский slug, тип «ТВ2» и сохраните.'**
  String get adminTv2UserGuide1;

  /// No description provided for @adminTv2UserGuide2.
  ///
  /// In ru, this message translates to:
  /// **'2. Пока страниц нет, просмотр пустой. Добавьте страницы в «Страницы и товары ТВ2» — настройки зависят от типа страницы.'**
  String get adminTv2UserGuide2;

  /// No description provided for @adminTv2UserGuide3.
  ///
  /// In ru, this message translates to:
  /// **'3. Для типа «Фон (видео)» настраиваются видео и оффер; для split — две колонки справа; для list — сетка и карточка.'**
  String get adminTv2UserGuide3;

  /// No description provided for @adminTv2UserGuide4.
  ///
  /// In ru, this message translates to:
  /// **'4. В превью в боковой панели задайте паузу между страницами и анимацию перехода, затем «Сохранить в экран».'**
  String get adminTv2UserGuide4;

  /// No description provided for @adminTv2PagesTimingTitle.
  ///
  /// In ru, this message translates to:
  /// **'Смена страниц'**
  String get adminTv2PagesTimingTitle;

  /// No description provided for @adminTv2PagesTimingHint.
  ///
  /// In ru, this message translates to:
  /// **'Сколько секунд показывать каждую страницу и как плавно переключаться на следующую.'**
  String get adminTv2PagesTimingHint;

  /// No description provided for @adminTv2PageTransitionLabel.
  ///
  /// In ru, this message translates to:
  /// **'Анимация перехода между страницами'**
  String get adminTv2PageTransitionLabel;

  /// No description provided for @adminTv2PageHoldLabel.
  ///
  /// In ru, this message translates to:
  /// **'Показ одной страницы: {seconds} с'**
  String adminTv2PageHoldLabel(int seconds);

  /// No description provided for @adminTv2TransitionDurationLabel.
  ///
  /// In ru, this message translates to:
  /// **'Длительность анимации: {ms} мс'**
  String adminTv2TransitionDurationLabel(int ms);

  /// No description provided for @adminTv2VariedTransitionsTitle.
  ///
  /// In ru, this message translates to:
  /// **'Чередовать переходы при видеофоне'**
  String get adminTv2VariedTransitionsTitle;

  /// No description provided for @adminTv2VariedTransitionsSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Если включено, при страницах с видео анимации сменяются по кругу (как раньше). Выключено — всегда выбранный выше тип.'**
  String get adminTv2VariedTransitionsSubtitle;

  /// No description provided for @adminTv2VideoOverlayTitle.
  ///
  /// In ru, this message translates to:
  /// **'Расположение текста на видео'**
  String get adminTv2VideoOverlayTitle;

  /// No description provided for @adminTv2VideoOverlayHorizontal.
  ///
  /// In ru, this message translates to:
  /// **'По горизонтали'**
  String get adminTv2VideoOverlayHorizontal;

  /// No description provided for @adminTv2VideoOverlayVertical.
  ///
  /// In ru, this message translates to:
  /// **'По вертикали'**
  String get adminTv2VideoOverlayVertical;

  /// No description provided for @adminTv2AlignStart.
  ///
  /// In ru, this message translates to:
  /// **'Слева'**
  String get adminTv2AlignStart;

  /// No description provided for @adminTv2AlignCenter.
  ///
  /// In ru, this message translates to:
  /// **'По центру'**
  String get adminTv2AlignCenter;

  /// No description provided for @adminTv2AlignEnd.
  ///
  /// In ru, this message translates to:
  /// **'Справа'**
  String get adminTv2AlignEnd;

  /// No description provided for @adminTv2AlignBottom.
  ///
  /// In ru, this message translates to:
  /// **'Снизу'**
  String get adminTv2AlignBottom;

  /// No description provided for @adminTv2AlignTop.
  ///
  /// In ru, this message translates to:
  /// **'Сверху'**
  String get adminTv2AlignTop;

  /// No description provided for @adminTv2AlignMiddle.
  ///
  /// In ru, this message translates to:
  /// **'По центру экрана'**
  String get adminTv2AlignMiddle;

  /// No description provided for @adminScreenTv2Pages.
  ///
  /// In ru, this message translates to:
  /// **'Страницы ТВ2'**
  String get adminScreenTv2Pages;

  /// No description provided for @adminScreenTv2PagesHint.
  ///
  /// In ru, this message translates to:
  /// **'Тип и порядок страниц; наполнение настраивается отдельно.'**
  String get adminScreenTv2PagesHint;

  /// No description provided for @adminScreenTv2SaveFirst.
  ///
  /// In ru, this message translates to:
  /// **'Сохраните экран с типом ТВ2, чтобы добавлять страницы.'**
  String get adminScreenTv2SaveFirst;

  /// No description provided for @adminScreenPageAdd.
  ///
  /// In ru, this message translates to:
  /// **'Добавить страницу'**
  String get adminScreenPageAdd;

  /// No description provided for @adminScreenPageTypeLabel.
  ///
  /// In ru, this message translates to:
  /// **'Тип новой страницы'**
  String get adminScreenPageTypeLabel;

  /// No description provided for @adminScreenPageItems.
  ///
  /// In ru, this message translates to:
  /// **'Элементов: {count}'**
  String adminScreenPageItems(int count);

  /// No description provided for @adminTv2PageTypeSplit.
  ///
  /// In ru, this message translates to:
  /// **'Разделённый экран (split)'**
  String get adminTv2PageTypeSplit;

  /// No description provided for @adminTv2PageTypeDrinks.
  ///
  /// In ru, this message translates to:
  /// **'Напитки (drinks)'**
  String get adminTv2PageTypeDrinks;

  /// No description provided for @adminTv2PageTypeCarousel.
  ///
  /// In ru, this message translates to:
  /// **'Карусель (carousel)'**
  String get adminTv2PageTypeCarousel;

  /// No description provided for @adminTv2PageTypeList.
  ///
  /// In ru, this message translates to:
  /// **'Список (list)'**
  String get adminTv2PageTypeList;

  /// No description provided for @adminTv2PageTypeVideoBg.
  ///
  /// In ru, this message translates to:
  /// **'Фон (видео)'**
  String get adminTv2PageTypeVideoBg;

  /// No description provided for @adminTv2OptionalVideoTitle.
  ///
  /// In ru, this message translates to:
  /// **'Видео под макетом (опционально)'**
  String get adminTv2OptionalVideoTitle;

  /// No description provided for @adminTv2OptionalVideoHint.
  ///
  /// In ru, this message translates to:
  /// **'Для split, list, drinks и carousel: ролик показывается за колонкой или сеткой, как на ТВ. Такие страницы можно чередовать со страницей «Фон (видео)» в одной ротации.'**
  String get adminTv2OptionalVideoHint;

  /// No description provided for @adminTv2OptionalVideoClear.
  ///
  /// In ru, this message translates to:
  /// **'Убрать видео'**
  String get adminTv2OptionalVideoClear;

  /// No description provided for @adminTv2OptionalPhotoTitle.
  ///
  /// In ru, this message translates to:
  /// **'Фото под макетом (опционально)'**
  String get adminTv2OptionalPhotoTitle;

  /// No description provided for @adminTv2OptionalPhotoHint.
  ///
  /// In ru, this message translates to:
  /// **'Статичная картинка на весь фон за колонкой или сеткой. Если задано и видео, и фото — на ТВ играет видео.'**
  String get adminTv2OptionalPhotoHint;

  /// No description provided for @adminTv2OptionalPhotoClear.
  ///
  /// In ru, this message translates to:
  /// **'Убрать фото'**
  String get adminTv2OptionalPhotoClear;

  /// No description provided for @adminTv2VideoBgPickPhoto.
  ///
  /// In ru, this message translates to:
  /// **'Выбрать изображение'**
  String get adminTv2VideoBgPickPhoto;

  /// No description provided for @adminTv2VideoBgClearPhoto.
  ///
  /// In ru, this message translates to:
  /// **'Убрать фото фона'**
  String get adminTv2VideoBgClearPhoto;

  /// No description provided for @adminTv2BackgroundFileEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Файл не выбран'**
  String get adminTv2BackgroundFileEmpty;

  /// No description provided for @adminTv2VideoBgTitle.
  ///
  /// In ru, this message translates to:
  /// **'Видеофон'**
  String get adminTv2VideoBgTitle;

  /// No description provided for @adminTv2VideoBgPickVideo.
  ///
  /// In ru, this message translates to:
  /// **'Выбрать видеофайл'**
  String get adminTv2VideoBgPickVideo;

  /// No description provided for @adminTv2VideoBgNoVideo.
  ///
  /// In ru, this message translates to:
  /// **'Видео не выбрано'**
  String get adminTv2VideoBgNoVideo;

  /// No description provided for @adminTv2VideoBgShowPhotos.
  ///
  /// In ru, this message translates to:
  /// **'Показывать фото блюд'**
  String get adminTv2VideoBgShowPhotos;

  /// No description provided for @adminTv2VideoBgModeMenu.
  ///
  /// In ru, this message translates to:
  /// **'Товар (из меню)'**
  String get adminTv2VideoBgModeMenu;

  /// No description provided for @adminTv2VideoBgModeCombo.
  ///
  /// In ru, this message translates to:
  /// **'Комбо'**
  String get adminTv2VideoBgModeCombo;

  /// No description provided for @adminTv2VideoBgSelectCombo.
  ///
  /// In ru, this message translates to:
  /// **'Выберите комбо'**
  String get adminTv2VideoBgSelectCombo;

  /// No description provided for @adminTv2VideoBgApplyCombo.
  ///
  /// In ru, this message translates to:
  /// **'Применить комбо'**
  String get adminTv2VideoBgApplyCombo;

  /// No description provided for @adminTv2VideoBgChooseHero.
  ///
  /// In ru, this message translates to:
  /// **'Выбрать товар из меню'**
  String get adminTv2VideoBgChooseHero;

  /// No description provided for @adminTv2VideoBgContentSource.
  ///
  /// In ru, this message translates to:
  /// **'Контент поверх видео'**
  String get adminTv2VideoBgContentSource;

  /// No description provided for @adminTv2VideoBgWhatToShowProduct.
  ///
  /// In ru, this message translates to:
  /// **'Что показывать из товара'**
  String get adminTv2VideoBgWhatToShowProduct;

  /// No description provided for @adminTv2VideoBgWhatToShowCombo.
  ///
  /// In ru, this message translates to:
  /// **'Что показывать из комбо'**
  String get adminTv2VideoBgWhatToShowCombo;

  /// No description provided for @adminTv2VideoBgShowDescription.
  ///
  /// In ru, this message translates to:
  /// **'Описание'**
  String get adminTv2VideoBgShowDescription;

  /// No description provided for @adminTv2VideoBgShowPrice.
  ///
  /// In ru, this message translates to:
  /// **'Цены'**
  String get adminTv2VideoBgShowPrice;

  /// No description provided for @adminTv2VideoBgShowComboComposition.
  ///
  /// In ru, this message translates to:
  /// **'Состав (позиции)'**
  String get adminTv2VideoBgShowComboComposition;

  /// No description provided for @adminTv2EditorVideoBgLayoutHint.
  ///
  /// In ru, this message translates to:
  /// **'На ТВ: видео на весь экран, снизу блок с названием и данными по выбранным пунктам (без дополнительных колонок).'**
  String get adminTv2EditorVideoBgLayoutHint;

  /// No description provided for @adminTv2EditorVideoBgExtraHint.
  ///
  /// In ru, this message translates to:
  /// **'Доп. позиции под карточкой (как на экране)'**
  String get adminTv2EditorVideoBgExtraHint;

  /// No description provided for @adminScreenPageDeleteTitle.
  ///
  /// In ru, this message translates to:
  /// **'Удалить страницу'**
  String get adminScreenPageDeleteTitle;

  /// No description provided for @adminScreenPageDeleteConfirm.
  ///
  /// In ru, this message translates to:
  /// **'Удалить страницу «{type}»?'**
  String adminScreenPageDeleteConfirm(String type);

  /// No description provided for @adminScreenPageAdded.
  ///
  /// In ru, this message translates to:
  /// **'Страница добавлена'**
  String get adminScreenPageAdded;

  /// No description provided for @adminScreenPageDeleted.
  ///
  /// In ru, this message translates to:
  /// **'Страница удалена'**
  String get adminScreenPageDeleted;

  /// No description provided for @adminTvSlideAppearanceTitle.
  ///
  /// In ru, this message translates to:
  /// **'Оформление слайда'**
  String get adminTvSlideAppearanceTitle;

  /// No description provided for @adminTvPresetLabel.
  ///
  /// In ru, this message translates to:
  /// **'Пресет'**
  String get adminTvPresetLabel;

  /// No description provided for @adminTvPresetCustom.
  ///
  /// In ru, this message translates to:
  /// **'Свой (текущий)'**
  String get adminTvPresetCustom;

  /// No description provided for @adminTvPresetDefault.
  ///
  /// In ru, this message translates to:
  /// **'По умолчанию'**
  String get adminTvPresetDefault;

  /// No description provided for @adminTvPresetCompact.
  ///
  /// In ru, this message translates to:
  /// **'Компакт'**
  String get adminTvPresetCompact;

  /// No description provided for @adminTvPresetBold.
  ///
  /// In ru, this message translates to:
  /// **'Акцент'**
  String get adminTvPresetBold;

  /// No description provided for @adminTvTransition.
  ///
  /// In ru, this message translates to:
  /// **'Анимация карусели'**
  String get adminTvTransition;

  /// No description provided for @adminTvTransitionFade.
  ///
  /// In ru, this message translates to:
  /// **'Затухание'**
  String get adminTvTransitionFade;

  /// No description provided for @adminTvTransitionSlide.
  ///
  /// In ru, this message translates to:
  /// **'Сдвиг'**
  String get adminTvTransitionSlide;

  /// No description provided for @adminTvTransitionSlideUp.
  ///
  /// In ru, this message translates to:
  /// **'Снизу вверх (свайп страницы)'**
  String get adminTvTransitionSlideUp;

  /// No description provided for @adminTvTransitionCrossFade.
  ///
  /// In ru, this message translates to:
  /// **'Перекрёстное затухание'**
  String get adminTvTransitionCrossFade;

  /// No description provided for @adminTvTransitionNone.
  ///
  /// In ru, this message translates to:
  /// **'Без анимации'**
  String get adminTvTransitionNone;

  /// No description provided for @adminTvTransitionScale.
  ///
  /// In ru, this message translates to:
  /// **'Масштаб'**
  String get adminTvTransitionScale;

  /// No description provided for @adminTvCategorySubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Подзаголовок категории'**
  String get adminTvCategorySubtitle;

  /// No description provided for @adminTvItemPrice.
  ///
  /// In ru, this message translates to:
  /// **'Цена позиции'**
  String get adminTvItemPrice;

  /// No description provided for @adminTvItemDivider.
  ///
  /// In ru, this message translates to:
  /// **'Разделитель между позициями'**
  String get adminTvItemDivider;

  /// No description provided for @adminTvItemDescription.
  ///
  /// In ru, this message translates to:
  /// **'Описание / состав позиции'**
  String get adminTvItemDescription;

  /// No description provided for @adminTvSlotsTitle.
  ///
  /// In ru, this message translates to:
  /// **'Порядок блоков (карточка ТВ1)'**
  String get adminTvSlotsTitle;

  /// No description provided for @adminTvSlotsHint.
  ///
  /// In ru, this message translates to:
  /// **'Перетащите: заголовок, подзаголовок, линия, позиции.'**
  String get adminTvSlotsHint;

  /// No description provided for @adminTv2ListAppearance.
  ///
  /// In ru, this message translates to:
  /// **'Строка списка ТВ2'**
  String get adminTv2ListAppearance;

  /// No description provided for @adminTv2ItemImage.
  ///
  /// In ru, this message translates to:
  /// **'Миниатюра'**
  String get adminTv2ItemImage;

  /// No description provided for @adminTvDraftTitle.
  ///
  /// In ru, this message translates to:
  /// **'Черновик контента превью'**
  String get adminTvDraftTitle;

  /// No description provided for @adminTvDraftHint.
  ///
  /// In ru, this message translates to:
  /// **'Демо-категория для превью (можно сохранить в config экрана).'**
  String get adminTvDraftHint;

  /// No description provided for @adminTvDraftApply.
  ///
  /// In ru, this message translates to:
  /// **'Применить демо-черновик'**
  String get adminTvDraftApply;

  /// No description provided for @adminTvDraftReset.
  ///
  /// In ru, this message translates to:
  /// **'Сбросить к данным каталога'**
  String get adminTvDraftReset;

  /// No description provided for @adminTvDraftSaveToConfig.
  ///
  /// In ru, this message translates to:
  /// **'Сохранить черновик в config экрана'**
  String get adminTvDraftSaveToConfig;

  /// No description provided for @adminTvDraftSavedToConfig.
  ///
  /// In ru, this message translates to:
  /// **'Черновик записан в config экрана'**
  String get adminTvDraftSavedToConfig;

  /// No description provided for @adminTvSlideSaveToScreen.
  ///
  /// In ru, this message translates to:
  /// **'Сохранить в экран'**
  String get adminTvSlideSaveToScreen;

  /// No description provided for @adminTvSlideSaving.
  ///
  /// In ru, this message translates to:
  /// **'Сохранение…'**
  String get adminTvSlideSaving;

  /// No description provided for @adminTvSlideSaved.
  ///
  /// In ru, this message translates to:
  /// **'Сохранено в экран'**
  String get adminTvSlideSaved;

  /// No description provided for @adminTvSlideSaveError.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось сохранить'**
  String get adminTvSlideSaveError;

  /// No description provided for @adminTvSlideNoScreenId.
  ///
  /// In ru, this message translates to:
  /// **'Сохранение доступно только для сохранённого экрана (откройте превью из списка экранов).'**
  String get adminTvSlideNoScreenId;

  /// No description provided for @adminTvStyleTitle.
  ///
  /// In ru, this message translates to:
  /// **'Цвета и шрифт (ТВ1)'**
  String get adminTvStyleTitle;

  /// No description provided for @adminTvStyleHexHint.
  ///
  /// In ru, this message translates to:
  /// **'Формат #RRGGBB; пусто — из темы'**
  String get adminTvStyleHexHint;

  /// No description provided for @adminTvStyleSlideBg.
  ///
  /// In ru, this message translates to:
  /// **'Фон слайда'**
  String get adminTvStyleSlideBg;

  /// No description provided for @adminTvStyleHeaderBg.
  ///
  /// In ru, this message translates to:
  /// **'Фон шапки'**
  String get adminTvStyleHeaderBg;

  /// No description provided for @adminTvStyleHeaderText.
  ///
  /// In ru, this message translates to:
  /// **'Текст шапки'**
  String get adminTvStyleHeaderText;

  /// No description provided for @adminTvStyleCategoryTitle.
  ///
  /// In ru, this message translates to:
  /// **'Заголовок категории'**
  String get adminTvStyleCategoryTitle;

  /// No description provided for @adminTvStyleCategorySubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Подзаголовок категории'**
  String get adminTvStyleCategorySubtitle;

  /// No description provided for @adminTvStyleItemName.
  ///
  /// In ru, this message translates to:
  /// **'Название позиции'**
  String get adminTvStyleItemName;

  /// No description provided for @adminTvStyleItemDesc.
  ///
  /// In ru, this message translates to:
  /// **'Описание позиции'**
  String get adminTvStyleItemDesc;

  /// No description provided for @adminTvStyleItemPrice.
  ///
  /// In ru, this message translates to:
  /// **'Цена позиции'**
  String get adminTvStyleItemPrice;

  /// No description provided for @adminTvStyleDivider.
  ///
  /// In ru, this message translates to:
  /// **'Разделители'**
  String get adminTvStyleDivider;

  /// No description provided for @adminTvStyleFontScale.
  ///
  /// In ru, this message translates to:
  /// **'Масштаб шрифта'**
  String get adminTvStyleFontScale;

  /// No description provided for @adminTvStyleReset.
  ///
  /// In ru, this message translates to:
  /// **'Сбросить цвета и масштаб'**
  String get adminTvStyleReset;

  /// No description provided for @adminMenuItemsTitle.
  ///
  /// In ru, this message translates to:
  /// **'Товары меню'**
  String get adminMenuItemsTitle;

  /// No description provided for @adminMenuItemsEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Позиций пока нет'**
  String get adminMenuItemsEmpty;

  /// No description provided for @adminMenuItemsLoadError.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось загрузить товары'**
  String get adminMenuItemsLoadError;

  /// No description provided for @adminMenuItemAdd.
  ///
  /// In ru, this message translates to:
  /// **'Добавить товар'**
  String get adminMenuItemAdd;

  /// No description provided for @adminMenuItemCreateTitle.
  ///
  /// In ru, this message translates to:
  /// **'Новый товар'**
  String get adminMenuItemCreateTitle;

  /// No description provided for @adminMenuItemEditTitle.
  ///
  /// In ru, this message translates to:
  /// **'Редактировать товар'**
  String get adminMenuItemEditTitle;

  /// No description provided for @adminMenuItemDelete.
  ///
  /// In ru, this message translates to:
  /// **'Удалить товар'**
  String get adminMenuItemDelete;

  /// No description provided for @adminMenuItemDeleteConfirm.
  ///
  /// In ru, this message translates to:
  /// **'Удалить «{name}»? Это действие нельзя отменить, если позиция не используется в заказах.'**
  String adminMenuItemDeleteConfirm(String name);

  /// No description provided for @adminMenuItemCreated.
  ///
  /// In ru, this message translates to:
  /// **'Товар создан'**
  String get adminMenuItemCreated;

  /// No description provided for @adminMenuItemUpdated.
  ///
  /// In ru, this message translates to:
  /// **'Товар сохранён'**
  String get adminMenuItemUpdated;

  /// No description provided for @adminMenuItemDeleted.
  ///
  /// In ru, this message translates to:
  /// **'Товар удалён'**
  String get adminMenuItemDeleted;

  /// No description provided for @adminMenuItemId.
  ///
  /// In ru, this message translates to:
  /// **'ID (латиница, без пробелов)'**
  String get adminMenuItemId;

  /// No description provided for @adminMenuItemIdHint.
  ///
  /// In ru, this message translates to:
  /// **'например burger-1'**
  String get adminMenuItemIdHint;

  /// No description provided for @adminMenuItemIdError.
  ///
  /// In ru, this message translates to:
  /// **'Введите id'**
  String get adminMenuItemIdError;

  /// No description provided for @adminMenuItemCategory.
  ///
  /// In ru, this message translates to:
  /// **'Категория'**
  String get adminMenuItemCategory;

  /// No description provided for @adminMenuItemPrice.
  ///
  /// In ru, this message translates to:
  /// **'Цена (число)'**
  String get adminMenuItemPrice;

  /// No description provided for @adminMenuItemPriceInvalid.
  ///
  /// In ru, this message translates to:
  /// **'Введите корректную цену'**
  String get adminMenuItemPriceInvalid;

  /// No description provided for @adminMenuItemPriceTextRu.
  ///
  /// In ru, this message translates to:
  /// **'Цена для экрана (рус.)'**
  String get adminMenuItemPriceTextRu;

  /// No description provided for @adminMenuItemPriceTextRuError.
  ///
  /// In ru, this message translates to:
  /// **'Введите текст цены'**
  String get adminMenuItemPriceTextRuError;

  /// No description provided for @adminMenuItemPriceTextTg.
  ///
  /// In ru, this message translates to:
  /// **'Цена (тоҷикӣ)'**
  String get adminMenuItemPriceTextTg;

  /// No description provided for @adminMenuItemPriceTextEn.
  ///
  /// In ru, this message translates to:
  /// **'Цена (English)'**
  String get adminMenuItemPriceTextEn;

  /// No description provided for @adminMenuItemSaleUnit.
  ///
  /// In ru, this message translates to:
  /// **'Единица измерения'**
  String get adminMenuItemSaleUnit;

  /// No description provided for @adminMenuItemPickImage.
  ///
  /// In ru, this message translates to:
  /// **'Загрузить фото на сервер'**
  String get adminMenuItemPickImage;

  /// No description provided for @adminMenuItemImageReadError.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось прочитать файл изображения'**
  String get adminMenuItemImageReadError;

  /// No description provided for @adminMenuItemUnitsLoadError.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось загрузить единицы измерения'**
  String get adminMenuItemUnitsLoadError;

  /// No description provided for @adminMenuItemUnitsEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Справочник единиц пуст — проверьте БД'**
  String get adminMenuItemUnitsEmpty;

  /// No description provided for @adminMenuItemUnitRequired.
  ///
  /// In ru, this message translates to:
  /// **'Выберите единицу измерения'**
  String get adminMenuItemUnitRequired;

  /// No description provided for @adminMenuItemImagePath.
  ///
  /// In ru, this message translates to:
  /// **'Путь к фото (uploads/…)'**
  String get adminMenuItemImagePath;

  /// No description provided for @adminMenuItemSku.
  ///
  /// In ru, this message translates to:
  /// **'Артикул (SKU)'**
  String get adminMenuItemSku;

  /// No description provided for @adminMenuItemBarcode.
  ///
  /// In ru, this message translates to:
  /// **'Штрихкод'**
  String get adminMenuItemBarcode;

  /// No description provided for @adminMenuItemTrackStock.
  ///
  /// In ru, this message translates to:
  /// **'Учитывать на складе'**
  String get adminMenuItemTrackStock;

  /// No description provided for @adminMenuItemAvailable.
  ///
  /// In ru, this message translates to:
  /// **'Доступен для продажи'**
  String get adminMenuItemAvailable;

  /// No description provided for @adminMenuItemDescriptionRu.
  ///
  /// In ru, this message translates to:
  /// **'Описание (рус.), необязательно'**
  String get adminMenuItemDescriptionRu;

  /// No description provided for @adminMenuItemCompositionRu.
  ///
  /// In ru, this message translates to:
  /// **'Состав (рус.), необязательно'**
  String get adminMenuItemCompositionRu;

  /// No description provided for @adminMenuItemVolumeVariantsJson.
  ///
  /// In ru, this message translates to:
  /// **'Объёмы и цены для ТВ (JSON), необязательно'**
  String get adminMenuItemVolumeVariantsJson;

  /// No description provided for @adminMenuItemVolumeVariantsHint.
  ///
  /// In ru, this message translates to:
  /// **'JSON-массив; у каждого элемента поля label (объём) и priceText (цена). Пусто — без вариантов.'**
  String get adminMenuItemVolumeVariantsHint;

  /// No description provided for @adminMenuItemVolumeVariantsInvalid.
  ///
  /// In ru, this message translates to:
  /// **'Некорректный JSON: нужен массив объектов с полями label и priceText'**
  String get adminMenuItemVolumeVariantsInvalid;

  /// No description provided for @actionDelete.
  ///
  /// In ru, this message translates to:
  /// **'Удалить'**
  String get actionDelete;

  /// No description provided for @adminOrdersHint.
  ///
  /// In ru, this message translates to:
  /// **'Продажи: оплаты со статусом «принята» за выбранные даты.'**
  String get adminOrdersHint;

  /// No description provided for @adminReportsSalesTitle.
  ///
  /// In ru, this message translates to:
  /// **'Продажи'**
  String get adminReportsSalesTitle;

  /// No description provided for @adminReportsSalesSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Только подтверждённые оплаты (касса / POS). Филиал по умолчанию — branch_1.'**
  String get adminReportsSalesSubtitle;

  /// No description provided for @adminReportsDateFrom.
  ///
  /// In ru, this message translates to:
  /// **'С даты'**
  String get adminReportsDateFrom;

  /// No description provided for @adminReportsDateTo.
  ///
  /// In ru, this message translates to:
  /// **'По дату'**
  String get adminReportsDateTo;

  /// No description provided for @adminReportsShow.
  ///
  /// In ru, this message translates to:
  /// **'Показать'**
  String get adminReportsShow;

  /// No description provided for @adminReportsLoadError.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось загрузить отчёт'**
  String get adminReportsLoadError;

  /// No description provided for @adminReportsPaymentsCount.
  ///
  /// In ru, this message translates to:
  /// **'Оплат: {count}'**
  String adminReportsPaymentsCount(int count);

  /// No description provided for @adminReportsTotal.
  ///
  /// In ru, this message translates to:
  /// **'Сумма: {amount}'**
  String adminReportsTotal(String amount);

  /// No description provided for @adminReportsEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Нет продаж за выбранный период'**
  String get adminReportsEmpty;

  /// No description provided for @adminReportsByMethod.
  ///
  /// In ru, this message translates to:
  /// **'По способу оплаты'**
  String get adminReportsByMethod;

  /// No description provided for @adminReportsByDay.
  ///
  /// In ru, this message translates to:
  /// **'По дням'**
  String get adminReportsByDay;

  /// No description provided for @adminReportsTable.
  ///
  /// In ru, this message translates to:
  /// **'Список оплат (до 500)'**
  String get adminReportsTable;

  /// No description provided for @adminReportsColumnTime.
  ///
  /// In ru, this message translates to:
  /// **'Дата и время'**
  String get adminReportsColumnTime;

  /// No description provided for @adminReportsColumnOrder.
  ///
  /// In ru, this message translates to:
  /// **'Заказ №'**
  String get adminReportsColumnOrder;

  /// No description provided for @adminReportsColumnMethod.
  ///
  /// In ru, this message translates to:
  /// **'Способ'**
  String get adminReportsColumnMethod;

  /// No description provided for @adminReportsColumnAmount.
  ///
  /// In ru, this message translates to:
  /// **'Сумма'**
  String get adminReportsColumnAmount;

  /// No description provided for @adminReportsColumnDay.
  ///
  /// In ru, this message translates to:
  /// **'День'**
  String get adminReportsColumnDay;

  /// No description provided for @adminReportsColumnCountShort.
  ///
  /// In ru, this message translates to:
  /// **'Оплат'**
  String get adminReportsColumnCountShort;

  /// No description provided for @adminReportsMethodCash.
  ///
  /// In ru, this message translates to:
  /// **'Наличные'**
  String get adminReportsMethodCash;

  /// No description provided for @adminReportsMethodCard.
  ///
  /// In ru, this message translates to:
  /// **'Карта'**
  String get adminReportsMethodCard;

  /// No description provided for @adminReportsMethodOnline.
  ///
  /// In ru, this message translates to:
  /// **'Онлайн'**
  String get adminReportsMethodOnline;

  /// No description provided for @adminReportsMethodDs.
  ///
  /// In ru, this message translates to:
  /// **'ДС'**
  String get adminReportsMethodDs;

  /// No description provided for @adminReportsMethodOther.
  ///
  /// In ru, this message translates to:
  /// **'Другое'**
  String get adminReportsMethodOther;

  /// No description provided for @actionRefreshMenu.
  ///
  /// In ru, this message translates to:
  /// **'Обновить меню'**
  String get actionRefreshMenu;

  /// No description provided for @actionExit.
  ///
  /// In ru, this message translates to:
  /// **'Выход'**
  String get actionExit;

  /// No description provided for @actionRetry.
  ///
  /// In ru, this message translates to:
  /// **'Повторить'**
  String get actionRetry;

  /// No description provided for @menuEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Нет позиций в меню'**
  String get menuEmpty;

  /// No description provided for @cartEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Корзина пуста'**
  String get cartEmpty;

  /// No description provided for @cartOrder.
  ///
  /// In ru, this message translates to:
  /// **'Заказ'**
  String get cartOrder;

  /// No description provided for @cartClear.
  ///
  /// In ru, this message translates to:
  /// **'Очистить'**
  String get cartClear;

  /// No description provided for @cartTotal.
  ///
  /// In ru, this message translates to:
  /// **'Итого'**
  String get cartTotal;

  /// No description provided for @roleAdmin.
  ///
  /// In ru, this message translates to:
  /// **'Админ'**
  String get roleAdmin;

  /// No description provided for @roleWarehouse.
  ///
  /// In ru, this message translates to:
  /// **'Кухня'**
  String get roleWarehouse;

  /// No description provided for @roleCashier.
  ///
  /// In ru, this message translates to:
  /// **'Касса'**
  String get roleCashier;

  /// No description provided for @roleExpeditor.
  ///
  /// In ru, this message translates to:
  /// **'Сборщик'**
  String get roleExpeditor;

  /// No description provided for @roleWaiter.
  ///
  /// In ru, this message translates to:
  /// **'Официант'**
  String get roleWaiter;

  /// No description provided for @posWorkspaceSubtitleCashier.
  ///
  /// In ru, this message translates to:
  /// **'Кассовое рабочее место • быстрая сборка заказа'**
  String get posWorkspaceSubtitleCashier;

  /// No description provided for @posWorkspaceSubtitleWaiter.
  ///
  /// In ru, this message translates to:
  /// **'Официант • заказы на стол (оплата на кассе)'**
  String get posWorkspaceSubtitleWaiter;

  /// No description provided for @posWaiterOrderTypesHint.
  ///
  /// In ru, this message translates to:
  /// **'С собой, на месте и доставка — всегда с выбором стола; оплата только на кассе.'**
  String get posWaiterOrderTypesHint;

  /// No description provided for @posTablePickWaiterHint.
  ///
  /// In ru, this message translates to:
  /// **'Для официанта стол обязателен — без стола оформить нельзя.'**
  String get posTablePickWaiterHint;

  /// No description provided for @posWaiterCannotPay.
  ///
  /// In ru, this message translates to:
  /// **'Официант не может принимать оплату — подойдите к кассе.'**
  String get posWaiterCannotPay;

  /// No description provided for @expeditorTitle.
  ///
  /// In ru, this message translates to:
  /// **'Сборка и выдача'**
  String get expeditorTitle;

  /// No description provided for @expeditorSectionBundling.
  ///
  /// In ru, this message translates to:
  /// **'Собрать'**
  String get expeditorSectionBundling;

  /// No description provided for @expeditorSectionPickup.
  ///
  /// In ru, this message translates to:
  /// **'Выдача'**
  String get expeditorSectionPickup;

  /// No description provided for @expeditorBundlingEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Нет заказов, ожидающих сборки'**
  String get expeditorBundlingEmpty;

  /// No description provided for @expeditorPickupEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Никто не ждёт выдачу'**
  String get expeditorPickupEmpty;

  /// No description provided for @expeditorTapToConfirm.
  ///
  /// In ru, this message translates to:
  /// **'Нажмите, проверить позиции и подтвердить'**
  String get expeditorTapToConfirm;

  /// No description provided for @expeditorTapToHandOut.
  ///
  /// In ru, this message translates to:
  /// **'Нажмите для выдачи по номеру'**
  String get expeditorTapToHandOut;

  /// No description provided for @expeditorDetailBundlingHint.
  ///
  /// In ru, this message translates to:
  /// **'Все кухни отметили готовность. Подтвердите — клиент увидит, что заказ готов.'**
  String get expeditorDetailBundlingHint;

  /// No description provided for @expeditorDetailPickupHint.
  ///
  /// In ru, this message translates to:
  /// **'Проверьте номер заказа и выдайте гостю или официанту.'**
  String get expeditorDetailPickupHint;

  /// No description provided for @expeditorConfirmReady.
  ///
  /// In ru, this message translates to:
  /// **'Готово'**
  String get expeditorConfirmReady;

  /// No description provided for @expeditorHandOut.
  ///
  /// In ru, this message translates to:
  /// **'Выдать заказ'**
  String get expeditorHandOut;

  /// No description provided for @expeditorQueueAllEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Очередь пуста'**
  String get expeditorQueueAllEmpty;

  /// No description provided for @expeditorItemsLine.
  ///
  /// In ru, this message translates to:
  /// **'{count} поз.'**
  String expeditorItemsLine(int count);

  /// No description provided for @posOpenExpeditor.
  ///
  /// In ru, this message translates to:
  /// **'Сборка / выдача'**
  String get posOpenExpeditor;

  /// No description provided for @posOrdersDialogTitle.
  ///
  /// In ru, this message translates to:
  /// **'Заказы'**
  String get posOrdersDialogTitle;

  /// No description provided for @posOrdersTabActive.
  ///
  /// In ru, this message translates to:
  /// **'Активные'**
  String get posOrdersTabActive;

  /// No description provided for @posOrdersTileSummary.
  ///
  /// In ru, this message translates to:
  /// **'сб. {bundling} · выд. {pickup}'**
  String posOrdersTileSummary(int bundling, int pickup);

  /// No description provided for @posOrdersWorkspaceValueHint.
  ///
  /// In ru, this message translates to:
  /// **'Открыть список'**
  String get posOrdersWorkspaceValueHint;

  /// No description provided for @posOrdersActiveEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Активных заказов пока нет'**
  String get posOrdersActiveEmpty;

  /// No description provided for @tooltipAppMenu.
  ///
  /// In ru, this message translates to:
  /// **'Меню'**
  String get tooltipAppMenu;

  /// No description provided for @languageRu.
  ///
  /// In ru, this message translates to:
  /// **'Русский'**
  String get languageRu;

  /// No description provided for @languageEn.
  ///
  /// In ru, this message translates to:
  /// **'English'**
  String get languageEn;

  /// No description provided for @languageTg.
  ///
  /// In ru, this message translates to:
  /// **'Тоҷикӣ'**
  String get languageTg;

  /// No description provided for @kitchenSectionCooking.
  ///
  /// In ru, this message translates to:
  /// **'Готовятся'**
  String get kitchenSectionCooking;

  /// No description provided for @kitchenSectionWaitingOthers.
  ///
  /// In ru, this message translates to:
  /// **'Ожидание других кухонь'**
  String get kitchenSectionWaitingOthers;

  /// No description provided for @kitchenEmptyCooking.
  ///
  /// In ru, this message translates to:
  /// **'Нет заказов в работе'**
  String get kitchenEmptyCooking;

  /// No description provided for @kitchenEmptyWaiting.
  ///
  /// In ru, this message translates to:
  /// **'Нет заказов на ожидании'**
  String get kitchenEmptyWaiting;

  /// No description provided for @kitchenAccept.
  ///
  /// In ru, this message translates to:
  /// **'Принято'**
  String get kitchenAccept;

  /// No description provided for @kitchenReady.
  ///
  /// In ru, this message translates to:
  /// **'Готово'**
  String get kitchenReady;

  /// No description provided for @kitchenWaitingHint.
  ///
  /// In ru, this message translates to:
  /// **'Ваша часть готова. Ожидайте другие кухни.'**
  String get kitchenWaitingHint;

  /// No description provided for @kitchenOrderNumber.
  ///
  /// In ru, this message translates to:
  /// **'Заказ {number}'**
  String kitchenOrderNumber(String number);

  /// No description provided for @queueBoardTitle.
  ///
  /// In ru, this message translates to:
  /// **'Очередь заказов'**
  String get queueBoardTitle;

  /// No description provided for @queueBoardSectionPreparing.
  ///
  /// In ru, this message translates to:
  /// **'Готовятся'**
  String get queueBoardSectionPreparing;

  /// No description provided for @queueBoardSectionReady.
  ///
  /// In ru, this message translates to:
  /// **'Готово к выдаче'**
  String get queueBoardSectionReady;

  /// No description provided for @queueBoardEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Нет заказов в очереди'**
  String get queueBoardEmpty;

  /// No description provided for @queueBoardTooltipOpen.
  ///
  /// In ru, this message translates to:
  /// **'Показ очереди'**
  String get queueBoardTooltipOpen;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ru', 'tg'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ru':
      return AppLocalizationsRu();
    case 'tg':
      return AppLocalizationsTg();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
