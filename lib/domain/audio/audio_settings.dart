const volumeSettingKey = 'volume';
const mutedSettingKey = 'muted';
const shuffleSettingKey = 'shuffle';

double? parseStoredVolume(String? value) {
  final parsed = double.tryParse(value?.trim() ?? '');
  if (parsed == null || !parsed.isFinite || parsed < 0 || parsed > 1) {
    return null;
  }
  return parsed;
}

bool? parseStoredBool(String? value) => switch (value?.trim()) {
  'true' => true,
  'false' => false,
  _ => null,
};
