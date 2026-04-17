/// UI locale (например `tg` ISO) → query `lang` для backend (словарь ru/tj/en).
String menuApiLanguageCode(String uiLanguageCode) {
  switch (uiLanguageCode) {
    case 'tg':
      return 'tj';
    default:
      return uiLanguageCode;
  }
}
