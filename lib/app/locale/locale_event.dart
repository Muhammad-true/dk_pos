import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

sealed class LocaleEvent extends Equatable {
  const LocaleEvent();

  @override
  List<Object?> get props => [];
}

final class LocaleStarted extends LocaleEvent {
  const LocaleStarted();
}

final class LocaleChanged extends LocaleEvent {
  const LocaleChanged(this.locale);

  final Locale locale;

  @override
  List<Object?> get props => [locale.languageCode];
}
