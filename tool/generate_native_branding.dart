import 'dart:io';

import 'package:image/image.dart' as image;

const _androidResPath = 'android/app/src/main/res';
const _jpegQuality = 88;

const _androidSources = <String, String>{
  'mipmap-xxxhdpi/ic_launcher.png': 'mipmap-xxxhdpi/ic_launcher.jpg',
  'drawable-xxxhdpi/ic_launcher_foreground.png':
      'drawable-xxxhdpi/ic_launcher_foreground.jpg',
  'drawable-xxxhdpi/android12splash.png':
      'drawable-xxxhdpi/android12splash.jpg',
};

const _generatedAndroidBitmapNames = <String>{
  'android12branding',
  'android12splash',
  'ic_launcher',
  'ic_launcher_foreground',
  'splash',
};

void main() {
  _requireProjectRoot();

  final xcodeProject = File('ios/Runner.xcodeproj/project.pbxproj');
  final xcodeProjectBackup = xcodeProject.readAsBytesSync();
  try {
    _runGenerator('flutter_launcher_icons');
  } finally {
    // The icon generator can rewrite an unrelated Xcode boolean setting on
    // recent Flutter templates. AppIcon is already configured in this project.
    xcodeProject.writeAsBytesSync(xcodeProjectBackup, flush: true);
  }

  _runGenerator('flutter_native_splash:create');
  _removeIosLaunchImage();
  _encodeSharedAndroidBitmaps();
  _removeRedundantAndroidBitmaps();
  _removeStaleDarkLaunchBackgrounds();
  _removeEmptyResourceDirectories();
  _trimAndroidXmlTrailingWhitespace();

  final retainedBytes = _androidSources.values
      .map((path) => File('$_androidResPath/$path').lengthSync())
      .fold<int>(0, (sum, bytes) => sum + bytes);
  stdout.writeln(
    'Native branding generated; retained Android bitmaps: '
    '${(retainedBytes / 1024).toStringAsFixed(1)} KiB.',
  );
}

void _requireProjectRoot() {
  if (!File('pubspec.yaml').existsSync() ||
      !Directory(_androidResPath).existsSync() ||
      !Directory('ios/Runner').existsSync()) {
    throw StateError('Run this command from the EDMM Flutter project root.');
  }
}

void _runGenerator(String packageCommand) {
  final result = Process.runSync(Platform.resolvedExecutable, [
    'run',
    packageCommand,
  ], runInShell: Platform.isWindows);
  stdout.write(result.stdout);
  stderr.write(result.stderr);
  if (result.exitCode != 0) {
    throw ProcessException(
      Platform.resolvedExecutable,
      ['run', packageCommand],
      'Branding generator failed.',
      result.exitCode,
    );
  }
}

void _removeIosLaunchImage() {
  final storyboard = File('ios/Runner/Base.lproj/LaunchScreen.storyboard');
  final source = storyboard.readAsStringSync();
  final newline = source.contains('\r\n') ? '\r\n' : '\n';
  final filtered = source
      .split(RegExp(r'\r?\n'))
      .where(
        (line) =>
            !line.contains('YRO-k0-Ey4') &&
            !line.contains('<image name="LaunchImage"'),
      )
      .join(newline);
  storyboard.writeAsStringSync(filtered, flush: true);

  final launchImages = Directory(
    'ios/Runner/Assets.xcassets/LaunchImage.imageset',
  );
  if (!launchImages.existsSync()) {
    return;
  }
  for (final entity in launchImages.listSync(followLinks: false)) {
    if (entity is Directory) {
      throw StateError(
        'Unexpected directory in LaunchImage asset set: ${entity.path}',
      );
    }
    entity.deleteSync();
  }
  launchImages.deleteSync();
}

void _encodeSharedAndroidBitmaps() {
  for (final entry in _androidSources.entries) {
    final source = File('$_androidResPath/${entry.key}');
    if (!source.existsSync()) {
      throw StateError(
        'Generated Android branding source is missing: ${entry.key}',
      );
    }

    final decoded = image.decodeImage(source.readAsBytesSync());
    if (decoded == null) {
      throw StateError('Unable to decode generated image: ${entry.key}');
    }

    final encoded = image.encodeJpg(
      decoded,
      quality: _jpegQuality,
      chroma: image.JpegChroma.yuv420,
    );
    File('$_androidResPath/${entry.value}')
      ..createSync(recursive: true)
      ..writeAsBytesSync(encoded, flush: true);
  }
}

void _removeRedundantAndroidBitmaps() {
  final retained = _androidSources.values
      .map((path) => File('$_androidResPath/$path').absolute.path)
      .map(_pathKey)
      .toSet();

  for (final entity in Directory(
    _androidResPath,
  ).listSync(recursive: true, followLinks: false)) {
    if (entity is! File) {
      continue;
    }
    final segments = entity.uri.pathSegments;
    final fileName = segments[segments.length - 1];
    final separator = fileName.lastIndexOf('.');
    if (separator < 0) {
      continue;
    }
    final extension = fileName.substring(separator + 1).toLowerCase();
    final name = fileName.substring(0, separator);
    if ((extension == 'png' || extension == 'jpg' || extension == 'jpeg') &&
        _generatedAndroidBitmapNames.contains(name) &&
        !retained.contains(_pathKey(entity.absolute.path))) {
      entity.deleteSync();
    }
  }
}

void _removeStaleDarkLaunchBackgrounds() {
  for (final path in const [
    '$_androidResPath/drawable-night/launch_background.xml',
    '$_androidResPath/drawable-night-v21/launch_background.xml',
  ]) {
    final file = File(path);
    if (file.existsSync()) {
      file.deleteSync();
    }
  }
}

void _removeEmptyResourceDirectories() {
  final root = Directory(_androidResPath).absolute;
  final directories =
      root
          .listSync(recursive: true, followLinks: false)
          .whereType<Directory>()
          .toList()
        ..sort((left, right) => right.path.length.compareTo(left.path.length));

  for (final directory in directories) {
    if (directory.listSync(followLinks: false).isEmpty) {
      directory.deleteSync();
    }
  }
}

void _trimAndroidXmlTrailingWhitespace() {
  for (final entity in Directory(
    _androidResPath,
  ).listSync(recursive: true, followLinks: false)) {
    if (entity is! File || !entity.path.toLowerCase().endsWith('.xml')) {
      continue;
    }
    final source = entity.readAsStringSync();
    final updated = source.replaceAll(
      RegExp(r'[ \t]+(?=\r?$)', multiLine: true),
      '',
    );
    if (updated != source) {
      entity.writeAsStringSync(updated, flush: true);
    }
  }
}

String _pathKey(String path) {
  final normalized = path.replaceAll('\\', '/');
  return Platform.isWindows ? normalized.toLowerCase() : normalized;
}
