import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('just_audio resolves to the repo-local editable fork', () {
    final packageConfigFile = File('.dart_tool/package_config.json');
    final packageConfig =
        jsonDecode(packageConfigFile.readAsStringSync())
            as Map<String, Object?>;
    final packages = (packageConfig['packages']! as List<Object?>)
        .cast<Map<String, Object?>>();

    final justAudio = packages.singleWhere(
      (package) => package['name'] == 'just_audio',
    );

    final actualRootUri = _resolvePackageRootUri(
      packageConfigFile,
      justAudio['rootUri']! as String,
    );
    final expectedRootUri = Directory(
      'packages/just_audio_edmm/just_audio',
    ).absolute.uri;

    expect(
      _withoutTrailingSlash(actualRootUri.normalizePath().toString()),
      _withoutTrailingSlash(expectedRootUri.normalizePath().toString()),
    );
  });
}

Uri _resolvePackageRootUri(File packageConfigFile, String rootUri) {
  final uri = Uri.parse(rootUri);
  if (uri.isAbsolute) {
    return uri;
  }

  return packageConfigFile.parent.absolute.uri.resolveUri(uri);
}

String _withoutTrailingSlash(String value) {
  if (value.endsWith('/')) {
    return value.substring(0, value.length - 1);
  }

  return value;
}
