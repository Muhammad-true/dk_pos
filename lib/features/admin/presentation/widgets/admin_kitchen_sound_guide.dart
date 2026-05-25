import 'package:flutter/material.dart';

/// Справочник по блоку «Кухня — новый заказ» в настройках звука админки.
class AdminKitchenSoundGuide extends StatelessWidget {
  const AdminKitchenSoundGuide({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final bodyStyle = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
      height: 1.45,
    );
    final titleStyle = theme.textTheme.labelLarge?.copyWith(
      fontWeight: FontWeight.w800,
      color: scheme.onSurface,
    );

    return Card(
      margin: EdgeInsets.zero,
      color: scheme.surfaceContainerLowest,
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: false,
        leading: Icon(Icons.menu_book_rounded, color: scheme.primary),
        title: Text(
          'Справочник: звук и TTS на кухне',
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          'Как настроить сигнал, загрузить свой файл, примеры',
          style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Text(
            'Когда срабатывает',
            style: titleStyle,
          ),
          const SizedBox(height: 6),
          Text(
            'На планшете кухни (вход под ролью «Кухня»), когда в колонке «Готовят» '
            'появляется новый заказ — с кассы, со стола или с сайта после принятия кассиром.',
            style: bodyStyle,
          ),
          const SizedBox(height: 14),
          Text('Порядок оповещения', style: titleStyle),
          const SizedBox(height: 6),
          _StepRow(
            number: '1',
            text: 'Короткий звуковой сигнал (см. ниже).',
            scheme: scheme,
          ),
          _StepRow(
            number: '2',
            text: 'Если включён TTS — голос произносит номер заказа после сигнала.',
            scheme: scheme,
          ),
          const SizedBox(height: 14),
          Text('Свой звук (MP3 / WAV)', style: titleStyle),
          const SizedBox(height: 6),
          _StepRow(number: '1', text: 'Нажмите «Загрузить» и выберите файл (.mp3, .wav, .ogg).', scheme: scheme),
          _StepRow(
            number: '2',
            text: 'В поле появится путь, например: uploads/audio/kitchen_bell.wav',
            scheme: scheme,
          ),
          _StepRow(
            number: '3',
            text: 'Нажмите внизу «Сохранить все звуки и TTS».',
            scheme: scheme,
          ),
          _StepRow(
            number: '4',
            text: 'На планшете кухни новый заказ подхватит настройки автоматически (обычно в течение минуты).',
            scheme: scheme,
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: scheme.primaryContainer.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              'Если поле «Путь звука» пустое — играет встроенный сигнал приложения. '
              'Свой файл не обязателен.',
              style: bodyStyle?.copyWith(color: scheme.onSurface),
            ),
          ),
          const SizedBox(height: 14),
          Text('Примеры настроек', style: titleStyle),
          const SizedBox(height: 8),
          _ExampleTable(scheme: scheme, bodyStyle: bodyStyle),
          const SizedBox(height: 14),
          Text('TTS (озвучка номера)', style: titleStyle),
          const SizedBox(height: 6),
          Text(
            'Переключатель «Озвучить номер заказа» — только голос после сигнала. '
            'Выключите, если поварам достаточно одного звонка.',
            style: bodyStyle,
          ),
          const SizedBox(height: 8),
          _Bullet(text: 'Скорость 0.48 — спокойная, разборчивая речь (рекомендуется).', style: bodyStyle),
          _Bullet(text: '0.30 — медленнее; 0.90 — быстрее.', style: bodyStyle),
          _Bullet(text: 'Язык ru-RU — русский; на устройстве должен быть установлен голос.', style: bodyStyle),
          _Bullet(
            text: 'Имя голоса — необязательно; оставьте пустым для системного голоса.',
            style: bodyStyle,
          ),
          const SizedBox(height: 14),
          Text('Проверка', style: titleStyle),
          const SizedBox(height: 6),
          _Bullet(text: 'Громкость медиа на планшете не на нуле.', style: bodyStyle),
          _Bullet(text: 'В шапке кухни отображается «· онлайн» (связь с сервером).', style: bodyStyle),
          _Bullet(text: 'Пробный заказ с кассы — карточка и звук без ручного обновления.', style: bodyStyle),
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.number,
    required this.text,
    required this.scheme,
  });

  final String number;
  final String text;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: scheme.primary,
              shape: BoxShape.circle,
            ),
            child: Text(
              number,
              style: TextStyle(
                color: scheme.onPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.4,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet({required this.text, this.style});

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('• ', style: style),
          Expanded(child: Text(text, style: style)),
        ],
      ),
    );
  }
}

class _ExampleTable extends StatelessWidget {
  const _ExampleTable({required this.scheme, this.bodyStyle});

  final ColorScheme scheme;
  final TextStyle? bodyStyle;

  @override
  Widget build(BuildContext context) {
    final headerStyle = bodyStyle?.copyWith(fontWeight: FontWeight.w800, color: scheme.onSurface);
    final cellStyle = bodyStyle;
    final border = TableBorder.all(color: scheme.outlineVariant, width: 1);

    TableRow row(List<String> cells, {bool header = false}) {
      return TableRow(
        children: cells
            .map(
              (c) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Text(c, style: header ? headerStyle : cellStyle),
              ),
            )
            .toList(),
      );
    }

    return Table(
      border: border,
      columnWidths: const {
        0: FlexColumnWidth(1.1),
        1: FlexColumnWidth(1.2),
        2: FlexColumnWidth(0.7),
        3: FlexColumnWidth(1.4),
      },
      children: [
        row(['Задача', 'Путь звука', 'TTS', 'Результат на кухне'], header: true),
        row(['Только звонок', 'пусто', 'Выкл', 'Встроенный сигнал']),
        row(['Свой звонок', 'uploads/audio/bell.wav', 'Выкл', 'Ваш файл один раз']),
        row(['Звонок + голос', 'пусто или свой', 'Вкл', 'Сигнал, затем «Новый заказ, номер…»']),
        row(['Тихая кухня', 'пусто', 'Выкл', 'Минимум: только короткий сигнал']),
      ],
    );
  }
}
