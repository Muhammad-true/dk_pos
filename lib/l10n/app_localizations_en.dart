// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Doner Kebab';

  @override
  String get loginTitle => 'Sign in';

  @override
  String get loginSubtitle => 'Doner Kebab POS';

  @override
  String get loginFormIntro => 'Sign in to use the point of sale.';

  @override
  String get fieldUsername => 'Username';

  @override
  String get fieldPassword => 'Password';

  @override
  String get fieldUsernameError => 'Enter username';

  @override
  String get fieldPasswordError => 'Enter password';

  @override
  String get actionSignIn => 'Sign in';

  @override
  String get posTitle => 'Cash register';

  @override
  String get adminTitle => 'Admin';

  @override
  String get adminHomeHint => 'Content and catalog tools will appear here.';

  @override
  String get adminNavOverview => 'Overview';

  @override
  String get adminNavUsers => 'Users';

  @override
  String get adminNavCatalog => 'Catalog';

  @override
  String get adminNavOrders => 'Orders';

  @override
  String get adminNavSettings => 'Settings';

  @override
  String get adminNavSettingsDrawerHint => 'Language and other app options';

  @override
  String get adminDrawerSectionNav => 'Sections';

  @override
  String get adminDrawerSectionLanguage => 'Interface language';

  @override
  String get adminNavOverviewDrawerHint => 'Summary and quick actions';

  @override
  String get adminNavUsersDrawerHint => 'Accounts and roles';

  @override
  String get adminNavCatalogDrawerHint => 'Menu categories and items';

  @override
  String get adminNavOrdersDrawerHint => 'Sales report by date range';

  @override
  String get adminDrawerSignOutHint => 'You will need to sign in again';

  @override
  String get adminUsersTitle => 'Users';

  @override
  String get adminUsersEmpty => 'No users yet';

  @override
  String get adminUsersAdd => 'Add';

  @override
  String get adminUsersEdit => 'Edit';

  @override
  String get adminUsersDelete => 'Delete';

  @override
  String get adminUsersColumnCreated => 'Created';

  @override
  String get adminUsersActions => 'Actions';

  @override
  String adminUsersConfirmDelete(String name) {
    return 'Delete user \"$name\"? This cannot be undone.';
  }

  @override
  String get adminUsersPasswordOptional =>
      'Leave blank to keep the current password';

  @override
  String get adminUsersPasswordMin => 'Password at least 6 characters';

  @override
  String get adminUsersLoadError => 'Could not load users';

  @override
  String get fieldRole => 'Role';

  @override
  String get actionCancel => 'Cancel';

  @override
  String get actionSave => 'Save';

  @override
  String get adminDashboardHeadline => 'Dashboard';

  @override
  String get adminDashboardBody =>
      'Summaries and quick actions will show up here.';

  @override
  String get adminCatalogHint =>
      'Menu categories and items for POS and digital menu.';

  @override
  String get adminCatalogManageTitle => 'Menu categories';

  @override
  String get adminCatalogEmpty => 'No categories yet';

  @override
  String get adminCatalogLoadError => 'Could not load categories';

  @override
  String get adminCategoryAdd => 'Add category';

  @override
  String get adminCategoryFormTitle => 'New category';

  @override
  String get adminCategoryNameRu => 'Name (Russian)';

  @override
  String get adminCategoryNameTg => 'Name (Tajik)';

  @override
  String get adminCategoryNameEn => 'Name (English)';

  @override
  String get adminCategorySubtitleRu => 'Subtitle (Russian), optional';

  @override
  String get adminCategorySubtitleTg => 'Subtitle (Tajik)';

  @override
  String get adminCategorySubtitleEn => 'Subtitle (English)';

  @override
  String get adminCategorySortOrder => 'Sort order';

  @override
  String get adminCategorySortInvalid => 'Enter a whole number';

  @override
  String get adminCategoryNameRuError => 'Enter a Russian name';

  @override
  String get adminCategoryCreated => 'Category created';

  @override
  String get adminCategoryParentLabel => 'Parent category';

  @override
  String get adminCategoryParentRoot => 'Root (top level)';

  @override
  String adminCategoryDepthLabel(int level) {
    return 'level $level';
  }

  @override
  String get posCatalogBack => 'Back';

  @override
  String get posCatalogSections => 'Sections';

  @override
  String get posCatalogNoSubcategories => 'No subcategories';

  @override
  String get posCatalogNoItemsHere => 'No items in this section';

  @override
  String get posCatalogPickCategory => 'Pick a section on the left';

  @override
  String get adminCatalogTabCategories => 'Categories';

  @override
  String get adminCatalogTabProducts => 'Products';

  @override
  String get adminCatalogTabScreens => 'TV screens';

  @override
  String get adminCatalogHubLead =>
      'Open each section on its own screen. Transitions use a smooth fade and slide.';

  @override
  String get adminCatalogHubCategoriesHint =>
      'Tree of menu categories and subtitles';

  @override
  String get adminCatalogHubProductsHint =>
      'Items, prices, images, and TV fields';

  @override
  String get adminCatalogHubCombosHint => 'Combo offers and line items';

  @override
  String get adminCatalogHubScreensHint =>
      'TV1–TV4 screens, preview, and config';

  @override
  String get adminScreensTitle => 'Digital menu screens';

  @override
  String get adminScreensHelpTitle => 'How to use';

  @override
  String get adminScreensHelpBody =>
      'TV2 (menu on the hall screen):\n1) Create a screen — type TV2, save.\n2) Open TV preview, then “TV2 pages & items” — add pages, column titles, and menu items (hero on the left, two columns on the right).\n3) In the preview drawer set time per page and transition animation, save to screen.\n\nTV1 carousel: slides come from tv1_page on items. Preview is a draft like on TV.';

  @override
  String get adminScreensLoadError => 'Could not load screens';

  @override
  String get adminScreensEmpty => 'No screens yet — create one for the TV box';

  @override
  String get adminScreenAdd => 'Add screen';

  @override
  String get adminScreenCreateTitle => 'New TV screen';

  @override
  String get adminScreenEditTitle => 'Edit TV screen';

  @override
  String get adminScreenDelete => 'Delete screen';

  @override
  String adminScreenDeleteConfirm(String name) {
    return 'Delete screen \"$name\"?';
  }

  @override
  String get adminScreenDeleted => 'Screen deleted';

  @override
  String get adminScreenName => 'Display name';

  @override
  String get adminScreenNameError => 'Enter a name';

  @override
  String get adminScreenSlug => 'Slug (latin, unique)';

  @override
  String get adminScreenSlugError => 'Enter a slug';

  @override
  String get adminScreenType => 'Layout template';

  @override
  String get adminScreenTypeCarousel =>
      'Menu carousel (TV1 items with tv1_page)';

  @override
  String get adminScreenTypeTv2 => 'TV2 — screen_pages';

  @override
  String get adminScreenTypeTv3 => 'TV3 — promotions';

  @override
  String get adminScreenTypeTv4 => 'TV4 — welcome & payment (config)';

  @override
  String get adminScreenActive => 'Active';

  @override
  String get adminScreenInactive => 'off';

  @override
  String get adminScreenDisplayTemplateTitle => 'Display template';

  @override
  String get adminScreenDisplayTemplateSubtitle =>
      'Grid and alignment for TV1/TV2 (no code).';

  @override
  String get adminScreenColsAuto => 'Auto (by screen width)';

  @override
  String get adminScreenTv1Columns => 'Category columns (TV1)';

  @override
  String get adminScreenTv2Columns => 'List columns (TV2)';

  @override
  String get adminScreenTv2ShowTemplate => 'TV2 display template';

  @override
  String get adminScreenTv2ShowTemplateClassic => 'Classic list';

  @override
  String get adminScreenTv2ShowTemplateVideoPromo =>
      'Video background + item or combo';

  @override
  String get adminScreenMaxCategoriesPerSlide =>
      'Max categories per slide (optional)';

  @override
  String get adminScreenMaxCategoriesHint =>
      'Leave empty for default — all categories on one slide.';

  @override
  String get adminScreenCenterGrid => 'Center grid on screen';

  @override
  String get adminScreenCenterGridSubtitle =>
      'Off: align the grid to the left.';

  @override
  String get adminScreenExtraConfigJson => 'Extra JSON (optional)';

  @override
  String get adminScreenExtraConfigHint =>
      'Rare keys (e.g. TV4). Form above overrides duplicate keys here.';

  @override
  String get adminScreenTemplateNotForType =>
      'Grid options apply to carousel (TV1) and TV2 only. Use extra JSON if needed.';

  @override
  String get adminScreenConfigJson => 'Extra JSON (optional)';

  @override
  String get adminScreenConfigInvalid => 'Invalid JSON in config';

  @override
  String get adminScreenCreated => 'Screen created';

  @override
  String get adminScreenUpdated => 'Screen saved';

  @override
  String get adminScreenPreview => 'Preview';

  @override
  String get adminScreenPreviewTooltip => 'Full-screen preview (draft)';

  @override
  String get adminTvPreviewTitle => 'TV preview';

  @override
  String get adminTvPreviewBanner =>
      'Draft preview. TV2 pages load from the server only for a saved screen.';

  @override
  String get adminTvPreviewClose => 'Close';

  @override
  String get adminTvPreviewError => 'Could not load preview';

  @override
  String get adminTvPreviewRetry => 'Retry';

  @override
  String get adminTv2OpenPagesEditor => 'TV2 pages & items…';

  @override
  String get adminTv3AppearanceTitle => 'TV3 — layout';

  @override
  String get adminTv3HeaderTitleLabel => 'Header title (drinks mode)';

  @override
  String get adminTv3HeaderTitleHint => 'Empty — hide the red header bar.';

  @override
  String get adminTv3PromoSloganLabel => 'Promo top line (promo carousel)';

  @override
  String get adminTv3PromoSloganHint =>
      'Empty — hide the top line for all slides (unless a slide sets its own). Up to 120 characters.';

  @override
  String get adminTv3PagePromoLineLabel => 'Top line for this slide only';

  @override
  String get adminTv3PagePromoLineHint =>
      'Empty — use the screen-wide slogan; set text to override just this slide (120 chars max).';

  @override
  String get adminTv3PromoSloganSave => 'Save slogan';

  @override
  String get adminTv3PromoSloganSaved => 'Slogan saved';

  @override
  String get adminTv3LayoutLabel => 'Layout mode';

  @override
  String get adminTv3LayoutPage3 => 'Drinks grid (Page3)';

  @override
  String get adminTv3LayoutPromos => 'Promotions carousel';

  @override
  String get adminTv3ContentHint =>
      'Categories and items come from the TV1 menu (page 3). Edit the carousel screen or menu in admin.';

  @override
  String get adminTv3PromoEditorTitle => 'TV3 — promo pages';

  @override
  String get adminTv3PromoEditorSubtitle =>
      'Each page is one slide in Promotions mode: one product (hero) or a combo. If pages exist for this screen, they replace the old promotions list.';

  @override
  String get adminTv3PageTypePromoProduct => 'Single product (slide)';

  @override
  String get adminTv3PageTypePromoCombo => 'Combo (slide)';

  @override
  String get adminTv3PromoSelectCombo => 'Combo';

  @override
  String get adminTv3PromoOpenCombosHint =>
      'Create combos in Catalog → Combos.';

  @override
  String get adminTv3PromoComboRequired =>
      'Select a combo before adding a combo page.';

  @override
  String get adminTv3PromoAddHero => 'Choose product for slide';

  @override
  String get adminTv3PromoHeroEmpty =>
      'No product — the slide will be empty until you add a hero.';

  @override
  String get adminTv3PromoReorderHint =>
      'TV slide order: hold the ⋮⋮ handle on a page and drag it up or down.';

  @override
  String get adminTv3PromoOrderSaved => 'Slide order saved';

  @override
  String get adminTv3OpenPromoPagesEditor => 'Promo pages (slides)…';

  @override
  String get adminTv4OpenSlidesEditor => 'TV4 slides (welcome & queue)…';

  @override
  String get adminTv4SlideDurationLabel => 'TV4 slide duration (sec)';

  @override
  String get adminTv4SlidesEditorTitle => 'TV4 slides';

  @override
  String get adminTv4SlidesEditorSubtitle =>
      'Screen pages: welcome/payment and order queue rotate on TV. Welcome text and QR stay in the screen config.';

  @override
  String get adminTv4PageTypeWelcomePay => 'Welcome & payment';

  @override
  String get adminTv4PageTypeQueue => 'Order queue';

  @override
  String get adminTv4PageAdded => 'Page added';

  @override
  String get adminTv4PageDeleted => 'Page deleted';

  @override
  String get adminTv4SlidesReorderHint => 'Hold ⋮⋮ and drag to reorder slides.';

  @override
  String get adminTv4SlidesOrderSaved => 'Slide order saved';

  @override
  String get adminTv4AddPage => 'Add page';

  @override
  String get adminTv3PromoSlideThemeLabel => 'Slide colors';

  @override
  String get adminTv3PromoSlideThemeRedBg => 'Red background, white text';

  @override
  String get adminTv3PromoSlideThemeWhiteBg => 'White background, red text';

  @override
  String get adminTv3PageTypePromoVideoBg => 'Full screen: video + text';

  @override
  String get adminTv3PageTypePromoPhotoBg => 'Full screen: photo + text';

  @override
  String get adminTv3MediaBgTitle => 'Background media';

  @override
  String get adminTv3MediaBgHint =>
      'Upload a file and optionally add on-screen captions (Promotions carousel mode).';

  @override
  String get adminTv3OverlayTitleLabel => 'On-screen title';

  @override
  String get adminTv3OverlaySubtitleLabel => 'Subtitle';

  @override
  String get adminTv3OverlayPriceLabel => 'Price / line';

  @override
  String get adminTv3MediaPickVideo => 'Choose video';

  @override
  String get adminTv3MediaPickPhoto => 'Choose photo';

  @override
  String get adminTv3MediaClear => 'Clear file';

  @override
  String get adminCatalogTabCombos => 'Combos';

  @override
  String get adminCombosTitle => 'Combos';

  @override
  String get adminCombosEmpty => 'No combos yet.';

  @override
  String get adminCombosCreateTitle => 'New combo';

  @override
  String get adminCombosNameRu => 'Name (RU)';

  @override
  String get adminCombosPriceRu => 'Price text (RU)';

  @override
  String get adminCombosCreated => 'Combo created';

  @override
  String get adminCombosLoadError => 'Could not load combos';

  @override
  String get adminCombosDescriptionRu => 'On-screen description (RU)';

  @override
  String get adminCombosUpdated => 'Combo saved';

  @override
  String get adminCombosImageSection => 'Combo photo';

  @override
  String get adminCombosRemoveImage => 'Remove photo';

  @override
  String get adminCombosValidityTitle => 'Validity (promo)';

  @override
  String get adminCombosDatesAny => 'No date limit';

  @override
  String get adminCombosDatesRange => 'Only between dates';

  @override
  String get adminCombosDateStart => 'From date';

  @override
  String get adminCombosDateEnd => 'To date';

  @override
  String get adminCombosTimesAny => 'All day (no time window)';

  @override
  String get adminCombosTimesRange => 'Only between hours each day';

  @override
  String get adminCombosTimeStart => 'From';

  @override
  String get adminCombosTimeEnd => 'To';

  @override
  String get adminCombosTimesBothRequired => 'Enter both «From» and «To» times';

  @override
  String get adminCombosValidityNow => 'Active now';

  @override
  String get adminCombosValidityOutside => 'Outside period — hidden on TVs';

  @override
  String get adminCombosDeleteCombo => 'Delete combo';

  @override
  String adminCombosDeleteComboConfirm(String name) {
    return 'Delete combo «$name»? Unlink it from menu or screens first if needed.';
  }

  @override
  String get adminCombosDeleted => 'Combo deleted';

  @override
  String get adminCombosDeleteErrorInUse =>
      'Cannot delete: combo is used in menu or on a screen';

  @override
  String get adminTv2EditorTitle => 'TV2 pages';

  @override
  String get adminTv2EditorSubtitle =>
      'A TV2 screen starts with no pages. Add a page and pick its type — only the relevant fields appear (split layout, list grid, video background, etc.).';

  @override
  String get adminTv2EditorPageAdded => 'Page added';

  @override
  String get adminTv2EditorTitlesSaved => 'Titles saved';

  @override
  String get adminTv2EditorItemAdded => 'Item added to page';

  @override
  String get adminTv2EditorItemRemoved => 'Item removed from page';

  @override
  String get adminTv2EditorPickItem => 'Pick a menu item';

  @override
  String get adminTv2EditorPickHintMulti =>
      'Select items. For «hero», only one product.';

  @override
  String adminTv2EditorAddSelectedButton(int count) {
    return 'Add selected ($count)';
  }

  @override
  String adminTv2EditorItemsAddedBatch(int count) {
    return 'Added items: $count';
  }

  @override
  String get adminTv2EditorSearch => 'Search by name or id';

  @override
  String get adminTv2EditorNoPages => 'No pages yet — add the first one.';

  @override
  String get adminTv2EditorReorderHint =>
      'TV2 page order on the TV: hold the ⋮⋮ handle on a row and drag up or down.';

  @override
  String get adminTv2EditorOrderSaved => 'Page order saved';

  @override
  String get adminTv2EditorPageLabel => 'Page';

  @override
  String get adminTv2EditorFirstColumn => 'Upper right section';

  @override
  String get adminTv2EditorSecondColumn => 'Lower right section';

  @override
  String get adminTv2EditorListTitleRu => 'First column title (Russian)';

  @override
  String get adminTv2EditorSecondTitleRu => 'Second column title (Russian)';

  @override
  String get adminTv2EditorListGridTitleRu => 'Grid title (Russian)';

  @override
  String get adminTv2EditorPageHintSplit =>
      'Two columns on the right (burgers / drinks style).';

  @override
  String get adminTv2EditorPageHintList =>
      'Product grid and a large card on the right.';

  @override
  String get adminTv2EditorPageHintVideoBg =>
      'Full-screen video, offer, optional product strips.';

  @override
  String get adminTv2EditorVideoBgComboNoMenuItems =>
      'Combo mode: items come from the combo; you don’t add menu rows here.';

  @override
  String get adminTv2EditorRoleHeroCardList => 'Right card';

  @override
  String get adminTv2EditorRoleListGrid => 'In grid';

  @override
  String get adminTv2EditorSaveTitles => 'Save titles';

  @override
  String get adminTv2EditorItemsSection => 'Items on page';

  @override
  String get adminTv2EditorAddAsRole => 'Add as';

  @override
  String get adminTv2EditorAddFromMenu => 'From menu';

  @override
  String get adminTv2EditorNoItemsOnPage => 'No items yet — add from the menu.';

  @override
  String get adminTv2EditorRoleHero => 'Hero (large left)';

  @override
  String get adminTv2EditorRoleList => 'First column';

  @override
  String get adminTv2EditorRoleHotdog => 'Second column';

  @override
  String get adminTv2EditorLayoutPreview => 'Layout preview';

  @override
  String get adminTv2EditorLayoutTitlePlaceholder => 'Title';

  @override
  String get adminTv2EditorLayoutHeroEmpty => 'No hero';

  @override
  String get adminTv2EditorLayoutListHint =>
      'List template: grid of all items.';

  @override
  String adminTv2EditorLayoutMore(int count) {
    return '+$count more';
  }

  @override
  String get adminTv2UserGuideTitle => 'How to set up the hall TV menu';

  @override
  String get adminTv2UserGuide1 =>
      '1. Create a screen: name, Latin slug, type TV2, save.';

  @override
  String get adminTv2UserGuide2 =>
      '2. With no pages, preview is empty. Add pages under “TV2 pages & items” — settings depend on page type.';

  @override
  String get adminTv2UserGuide3 =>
      '3. “Video background” uses video + offer; split uses two right columns; list uses a grid and card.';

  @override
  String get adminTv2UserGuide4 =>
      '4. In the preview drawer set pause between pages and transition, then “Save to screen”.';

  @override
  String get adminTv2PagesTimingTitle => 'Page changes';

  @override
  String get adminTv2PagesTimingHint =>
      'How long each page stays on screen and how it animates to the next.';

  @override
  String get adminTv2PageTransitionLabel => 'Transition between pages';

  @override
  String adminTv2PageHoldLabel(int seconds) {
    return 'Time on one page: $seconds s';
  }

  @override
  String adminTv2TransitionDurationLabel(int ms) {
    return 'Animation length: $ms ms';
  }

  @override
  String get adminTv2VariedTransitionsTitle =>
      'Rotate transitions with video background';

  @override
  String get adminTv2VariedTransitionsSubtitle =>
      'When on, pages with video cycle slide/fade/scale. When off, the selected transition is always used.';

  @override
  String get adminTv2VideoOverlayTitle => 'Text position on video';

  @override
  String get adminTv2VideoOverlayHorizontal => 'Horizontal';

  @override
  String get adminTv2VideoOverlayVertical => 'Vertical';

  @override
  String get adminTv2AlignStart => 'Left';

  @override
  String get adminTv2AlignCenter => 'Center';

  @override
  String get adminTv2AlignEnd => 'Right';

  @override
  String get adminTv2AlignBottom => 'Bottom';

  @override
  String get adminTv2AlignTop => 'Top';

  @override
  String get adminTv2AlignMiddle => 'Middle of screen';

  @override
  String get adminScreenTv2Pages => 'TV2 pages';

  @override
  String get adminScreenTv2PagesHint =>
      'Page type and order; content is configured separately.';

  @override
  String get adminScreenTv2SaveFirst =>
      'Save the screen as TV2 to manage pages.';

  @override
  String get adminScreenPageAdd => 'Add page';

  @override
  String get adminScreenPageTypeLabel => 'New page type';

  @override
  String adminScreenPageItems(int count) {
    return 'Items: $count';
  }

  @override
  String get adminTv2PageTypeSplit => 'Split layout (split)';

  @override
  String get adminTv2PageTypeDrinks => 'Drinks (drinks)';

  @override
  String get adminTv2PageTypeCarousel => 'Carousel (carousel)';

  @override
  String get adminTv2PageTypeList => 'List (list)';

  @override
  String get adminTv2PageTypeVideoBg => 'Video background';

  @override
  String get adminTv2OptionalVideoTitle => 'Video under layout (optional)';

  @override
  String get adminTv2OptionalVideoHint =>
      'For split, list, drinks and carousel: the clip plays behind the layout, same as on TV. You can rotate these pages with a full-screen «Video background» page.';

  @override
  String get adminTv2OptionalVideoClear => 'Remove video';

  @override
  String get adminTv2OptionalPhotoTitle => 'Photo under layout (optional)';

  @override
  String get adminTv2OptionalPhotoHint =>
      'Static full-screen image behind the layout. If both video and photo are set, TV plays video.';

  @override
  String get adminTv2OptionalPhotoClear => 'Remove photo';

  @override
  String get adminTv2VideoBgPickPhoto => 'Choose image';

  @override
  String get adminTv2VideoBgClearPhoto => 'Clear background photo';

  @override
  String get adminTv2BackgroundFileEmpty => 'No file selected';

  @override
  String get adminTv2VideoBgTitle => 'Video background';

  @override
  String get adminTv2VideoBgPickVideo => 'Choose video file';

  @override
  String get adminTv2VideoBgNoVideo => 'No video selected';

  @override
  String get adminTv2VideoBgShowPhotos => 'Show dish photos';

  @override
  String get adminTv2VideoBgModeMenu => 'Product (from menu)';

  @override
  String get adminTv2VideoBgModeCombo => 'Combo';

  @override
  String get adminTv2VideoBgSelectCombo => 'Select a combo';

  @override
  String get adminTv2VideoBgApplyCombo => 'Apply combo';

  @override
  String get adminTv2VideoBgChooseHero => 'Choose menu item';

  @override
  String get adminTv2VideoBgContentSource => 'Content over video';

  @override
  String get adminTv2VideoBgWhatToShowProduct =>
      'What to show from the product';

  @override
  String get adminTv2VideoBgWhatToShowCombo => 'What to show from the combo';

  @override
  String get adminTv2VideoBgShowDescription => 'Description';

  @override
  String get adminTv2VideoBgShowPrice => 'Prices';

  @override
  String get adminTv2VideoBgShowComboComposition => 'Composition (line items)';

  @override
  String get adminTv2EditorVideoBgLayoutHint =>
      'On TV: full-screen video; bottom block with name and the fields you enable (no extra columns).';

  @override
  String get adminTv2EditorVideoBgExtraHint =>
      'Extra items below the card (as on screen)';

  @override
  String get adminScreenPageDeleteTitle => 'Delete page';

  @override
  String adminScreenPageDeleteConfirm(String type) {
    return 'Delete page \"$type\"?';
  }

  @override
  String get adminScreenPageAdded => 'Page added';

  @override
  String get adminScreenPageDeleted => 'Page deleted';

  @override
  String get adminTvSlideAppearanceTitle => 'Slide appearance';

  @override
  String get adminTvPresetLabel => 'Preset';

  @override
  String get adminTvPresetCustom => 'Custom (current)';

  @override
  String get adminTvPresetDefault => 'Default';

  @override
  String get adminTvPresetCompact => 'Compact';

  @override
  String get adminTvPresetBold => 'Bold';

  @override
  String get adminTvTransition => 'Carousel transition';

  @override
  String get adminTvTransitionFade => 'Fade';

  @override
  String get adminTvTransitionSlide => 'Slide';

  @override
  String get adminTvTransitionSlideUp => 'Bottom to top (page swipe)';

  @override
  String get adminTvTransitionCrossFade => 'Cross-fade';

  @override
  String get adminTvTransitionNone => 'None';

  @override
  String get adminTvTransitionScale => 'Scale';

  @override
  String get adminTvCategorySubtitle => 'Category subtitle';

  @override
  String get adminTvItemPrice => 'Item price';

  @override
  String get adminTvItemDivider => 'Divider between items';

  @override
  String get adminTvItemDescription => 'Item description / composition';

  @override
  String get adminTvSlotsTitle => 'Block order (TV1 card)';

  @override
  String get adminTvSlotsHint =>
      'Drag to reorder title, subtitle, divider, items.';

  @override
  String get adminTv2ListAppearance => 'TV2 list row';

  @override
  String get adminTv2ItemImage => 'Thumbnail image';

  @override
  String get adminTvDraftTitle => 'Preview content draft';

  @override
  String get adminTvDraftHint =>
      'Demo category and items for preview only (optional save to screen config).';

  @override
  String get adminTvDraftApply => 'Apply demo draft';

  @override
  String get adminTvDraftReset => 'Reset to catalog data';

  @override
  String get adminTvDraftSaveToConfig => 'Save draft to screen config';

  @override
  String get adminTvDraftSavedToConfig => 'Draft saved in screen config';

  @override
  String get adminTvSlideSaveToScreen => 'Save to screen';

  @override
  String get adminTvSlideSaving => 'Saving…';

  @override
  String get adminTvSlideSaved => 'Saved to screen';

  @override
  String get adminTvSlideSaveError => 'Could not save';

  @override
  String get adminTvSlideNoScreenId =>
      'Save is only available for a saved screen (open preview from the screen list).';

  @override
  String get adminTvStyleTitle => 'Colors & font (TV1)';

  @override
  String get adminTvStyleHexHint => 'Hex #RRGGBB, leave empty to use theme';

  @override
  String get adminTvStyleSlideBg => 'Slide background';

  @override
  String get adminTvStyleHeaderBg => 'Header background';

  @override
  String get adminTvStyleHeaderText => 'Header text';

  @override
  String get adminTvStyleCategoryTitle => 'Category title';

  @override
  String get adminTvStyleCategorySubtitle => 'Category subtitle';

  @override
  String get adminTvStyleItemName => 'Item name';

  @override
  String get adminTvStyleItemDesc => 'Item description';

  @override
  String get adminTvStyleItemPrice => 'Item price';

  @override
  String get adminTvStyleDivider => 'Dividers';

  @override
  String get adminTvStyleFontScale => 'Font scale';

  @override
  String get adminTvStyleReset => 'Reset colors & scale';

  @override
  String get adminMenuItemsTitle => 'Menu products';

  @override
  String get adminMenuItemsEmpty => 'No products yet';

  @override
  String get adminMenuItemsLoadError => 'Could not load products';

  @override
  String get adminMenuItemAdd => 'Add product';

  @override
  String get adminMenuItemCreateTitle => 'New product';

  @override
  String get adminMenuItemEditTitle => 'Edit product';

  @override
  String get adminMenuItemDelete => 'Delete product';

  @override
  String adminMenuItemDeleteConfirm(String name) {
    return 'Delete \"$name\"? This cannot be undone if the product is not referenced elsewhere.';
  }

  @override
  String get adminMenuItemCreated => 'Product created';

  @override
  String get adminMenuItemUpdated => 'Product saved';

  @override
  String get adminMenuItemDeleted => 'Product deleted';

  @override
  String get adminMenuItemId => 'ID (latin, no spaces)';

  @override
  String get adminMenuItemIdHint => 'e.g. burger-1';

  @override
  String get adminMenuItemIdError => 'Enter an id';

  @override
  String get adminMenuItemCategory => 'Category';

  @override
  String get adminMenuItemPrice => 'Price (number)';

  @override
  String get adminMenuItemPriceInvalid => 'Enter a valid price';

  @override
  String get adminMenuItemPriceTextRu => 'Display price (Russian)';

  @override
  String get adminMenuItemPriceTextRuError => 'Enter price text';

  @override
  String get adminMenuItemPriceTextTg => 'Price (Tajik)';

  @override
  String get adminMenuItemPriceTextEn => 'Price (English)';

  @override
  String get adminMenuItemSaleUnit => 'Unit of measure';

  @override
  String get adminMenuItemPickImage => 'Upload photo to server';

  @override
  String get adminMenuItemImageReadError => 'Could not read the image file';

  @override
  String get adminMenuItemUnitsLoadError => 'Could not load units of measure';

  @override
  String get adminMenuItemUnitsEmpty =>
      'Units catalog is empty — check the database';

  @override
  String get adminMenuItemUnitRequired => 'Select a unit of measure';

  @override
  String get adminMenuItemImagePath => 'Image path (uploads/…)';

  @override
  String get adminMenuItemSku => 'SKU';

  @override
  String get adminMenuItemBarcode => 'Barcode';

  @override
  String get adminMenuItemTrackStock => 'Track stock';

  @override
  String get adminMenuItemAvailable => 'Available for sale';

  @override
  String get adminMenuItemDescriptionRu => 'Description (Russian), optional';

  @override
  String get adminMenuItemCompositionRu => 'Ingredients (Russian), optional';

  @override
  String get adminMenuItemVolumeVariantsJson =>
      'TV volumes & prices (JSON), optional';

  @override
  String get adminMenuItemVolumeVariantsHint =>
      'JSON array; each item has label (volume) and priceText. Leave empty for no variants.';

  @override
  String get adminMenuItemVolumeVariantsInvalid =>
      'Invalid JSON: expected an array of objects with label and priceText';

  @override
  String get actionDelete => 'Delete';

  @override
  String get adminOrdersHint =>
      'Sales: accepted payments for the selected dates.';

  @override
  String get adminReportsSalesTitle => 'Sales';

  @override
  String get adminReportsSalesSubtitle =>
      'Accepted payments only. Default branch: branch_1.';

  @override
  String get adminReportsDateFrom => 'From date';

  @override
  String get adminReportsDateTo => 'To date';

  @override
  String get adminReportsShow => 'Show';

  @override
  String get adminReportsLoadError => 'Could not load report';

  @override
  String adminReportsPaymentsCount(int count) {
    return 'Payments: $count';
  }

  @override
  String adminReportsTotal(String amount) {
    return 'Total: $amount';
  }

  @override
  String get adminReportsEmpty => 'No sales in this period';

  @override
  String get adminReportsByMethod => 'By payment method';

  @override
  String get adminReportsByDay => 'By day';

  @override
  String get adminReportsTable => 'Payments (up to 500)';

  @override
  String get adminReportsColumnTime => 'Date & time';

  @override
  String get adminReportsColumnOrder => 'Order #';

  @override
  String get adminReportsColumnMethod => 'Method';

  @override
  String get adminReportsColumnAmount => 'Amount';

  @override
  String get adminReportsColumnDay => 'Day';

  @override
  String get adminReportsColumnCountShort => 'Count';

  @override
  String get adminReportsMethodCash => 'Cash';

  @override
  String get adminReportsMethodCard => 'Card';

  @override
  String get adminReportsMethodOnline => 'Online';

  @override
  String get adminReportsMethodDs => 'DS';

  @override
  String get adminReportsMethodOther => 'Other';

  @override
  String get actionRefreshMenu => 'Refresh menu';

  @override
  String get actionExit => 'Sign out';

  @override
  String get actionRetry => 'Retry';

  @override
  String get menuEmpty => 'No menu items';

  @override
  String get cartEmpty => 'Cart is empty';

  @override
  String get cartOrder => 'Order';

  @override
  String get cartClear => 'Clear';

  @override
  String get cartTotal => 'Total';

  @override
  String get roleAdmin => 'Admin';

  @override
  String get roleWarehouse => 'Kitchen';

  @override
  String get roleCashier => 'Cashier';

  @override
  String get roleExpeditor => 'Expeditor';

  @override
  String get roleWaiter => 'Waiter';

  @override
  String get posWorkspaceSubtitleCashier =>
      'Cashier workspace • quick order assembly';

  @override
  String get posWorkspaceSubtitleWaiter =>
      'Waiter • table orders (pay at cashier)';

  @override
  String get posWaiterOrderTypesHint =>
      'Takeaway, dine-in, and delivery always require a table; payment only at the cashier.';

  @override
  String get posTablePickWaiterHint =>
      'Waiters must pick a table — dine-in without a table is not available.';

  @override
  String get posWaiterCannotPay =>
      'Waiters cannot take payment — please use the cashier.';

  @override
  String get expeditorTitle => 'Bundling & handoff';

  @override
  String get expeditorSectionBundling => 'Bundle';

  @override
  String get expeditorSectionPickup => 'Pickup';

  @override
  String get expeditorBundlingEmpty => 'No orders waiting to bundle';

  @override
  String get expeditorPickupEmpty => 'No orders waiting for pickup';

  @override
  String get expeditorTapToConfirm => 'Tap to review and confirm';

  @override
  String get expeditorTapToHandOut => 'Tap to hand out by number';

  @override
  String get expeditorDetailBundlingHint =>
      'All kitchen stations are done. Confirm so the customer sees the order is ready.';

  @override
  String get expeditorDetailPickupHint =>
      'Check the order number and hand to the guest or waiter.';

  @override
  String get expeditorConfirmReady => 'Ready';

  @override
  String get expeditorHandOut => 'Hand out order';

  @override
  String get expeditorQueueAllEmpty => 'Queue is empty';

  @override
  String expeditorItemsLine(int count) {
    return '$count items';
  }

  @override
  String get posOpenExpeditor => 'Bundling / handoff';

  @override
  String get posOrdersDialogTitle => 'Orders';

  @override
  String get posOrdersTabActive => 'Active';

  @override
  String posOrdersTileSummary(int bundling, int pickup) {
    return 'bundle $bundling · pickup $pickup';
  }

  @override
  String get posOrdersWorkspaceValueHint => 'Open list';

  @override
  String get posOrdersActiveEmpty => 'No active orders yet';

  @override
  String get tooltipAppMenu => 'Menu';

  @override
  String get languageRu => 'Russian';

  @override
  String get languageEn => 'English';

  @override
  String get languageTg => 'Tajik';

  @override
  String get kitchenSectionCooking => 'In progress';

  @override
  String get kitchenSectionWaitingOthers => 'Waiting on other stations';

  @override
  String get kitchenEmptyCooking => 'No orders in progress';

  @override
  String get kitchenEmptyWaiting => 'Nothing waiting';

  @override
  String get kitchenAccept => 'Accepted';

  @override
  String get kitchenReady => 'Done';

  @override
  String get kitchenWaitingHint =>
      'Your part is done. Waiting on other kitchens.';

  @override
  String kitchenOrderNumber(String number) {
    return 'Order $number';
  }

  @override
  String get queueBoardTitle => 'Order queue';

  @override
  String get queueBoardSectionPreparing => 'Preparing';

  @override
  String get queueBoardSectionReady => 'Ready for pickup';

  @override
  String get queueBoardEmpty => 'Queue is empty';

  @override
  String get queueBoardTooltipOpen => 'Queue display';
}
