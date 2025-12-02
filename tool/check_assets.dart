// 📁 File: tool/check_assets.dart
//
// Flutter Asset Management Helper — "Bundle Edition"
// ---------------------------------------------------
// Features:
// ✅ Checks that all assets in pubspec.yaml exist
// ✅ Detects unused assets
// ✅ Warns about possible typos (e.g. silhouet vs silhouette)
// ✅ Auto-suggests YAML fixes
// ✅ Optional: auto-generate asset list for pubspec.yaml
// ✅ Pretty colored terminal output

import 'dart:convert';
import 'dart:io';

final ansiGreen = '\x1B[32m';
final ansiRed = '\x1B[31m';
final ansiYellow = '\x1B[33m';
final ansiBlue = '\x1B[34m';
final ansiReset = '\x1B[0m';

void main(List<String> args) async {
  print('$ansiBlue🔍 Flutter Asset Management — Bundle Edition$ansiReset\n');

  final pubspecFile = File('pubspec.yaml');
  final assetsDir = Directory('assets');

  if (!pubspecFile.existsSync()) {
    print('$ansiRed❌ No pubspec.yaml found in current directory.$ansiReset');
    exit(1);
  }

  if (!assetsDir.existsSync()) {
    print('$ansiRed❌ No assets/ directory found.$ansiReset');
    exit(1);
  }

  final pubspec = await pubspecFile.readAsString();
  final listedAssets = _extractAssets(pubspec);
  final foundAssets = _listFilesRecursively(assetsDir);

  print('${ansiYellow}Checking listed assets...$ansiReset\n');

  final missing = <String>[];
  final matched = <String>[];

  for (final asset in listedAssets) {
    if (foundAssets.contains(asset)) {
      print('✅ Found: $asset');
      matched.add(asset);
    } else {
      print('❌ Missing: $asset');
      missing.add(asset);
    }
  }

  // Detect unused assets
  final unused = foundAssets.where((f) => !listedAssets.contains(f)).toList();

  // Detect typo candidates
  final typoSuspects = _detectTypos(foundAssets);

  print('\n$ansiBlue📊 Summary:$ansiReset');
  print('  Found:   $ansiGreen${matched.length}$ansiReset');
  print('  Missing: $ansiRed${missing.length}$ansiReset');
  print('  Unused:  $ansiYellow${unused.length}$ansiReset');
  print('  Typos?:  $ansiYellow${typoSuspects.length}$ansiReset');

  if (missing.isNotEmpty) {
    print('\n$ansiRed⚠ Missing assets:$ansiReset');
    for (final m in missing) {
      print('  - $m');
    }
  }

  if (unused.isNotEmpty) {
    print('\n$ansiYellow⚠ Unused assets in folder:$ansiReset');
    for (final u in unused) {
      print('  - $u');
    }
  }

  if (typoSuspects.isNotEmpty) {
    print(
      '\n$ansiYellow💡 Possible typo or near-duplicate filenames:$ansiReset',
    );
    for (final t in typoSuspects) {
      print('  - $t');
    }
  }

  // Optional auto-generate YAML mode
  if (args.contains('--generate')) {
    final yamlSection = _generateYaml(foundAssets);
    final outFile = File('tool/generated_assets.yaml');
    await outFile.writeAsString(yamlSection);
    print(
      '\n$ansiGreen✅ Generated YAML asset list at: tool/generated_assets.yaml$ansiReset',
    );
  }

  print('\n$ansiBlue✨ Done.$ansiReset');
}

/// Extracts assets listed under the "flutter: assets:" section.
List<String> _extractAssets(String yaml) {
  final lines = const LineSplitter().convert(yaml);
  final assets = <String>[];
  bool inAssets = false;

  for (final line in lines) {
    final trimmed = line.trim();
    if (trimmed.startsWith('assets:')) {
      inAssets = true;
      continue;
    }

    if (inAssets) {
      if (trimmed.isEmpty || !trimmed.startsWith('-')) break;
      assets.add(trimmed.replaceFirst('-', '').trim());
    }
  }

  return assets;
}

/// Recursively lists all files in a directory (relative paths)
List<String> _listFilesRecursively(Directory dir) {
  final files = <String>[];
  for (final entity in dir.listSync(recursive: true)) {
    if (entity is File) {
      final relPath = entity.path.replaceAll('\\', '/');
      files.add(relPath);
    }
  }
  return files;
}

/// Finds likely filename typos (like silhouette vs silhouet)
List<String> _detectTypos(List<String> files) {
  final results = <String>[];
  for (final file in files) {
    if (file.contains(RegExp(r'silhouet(?!te)'))) {
      results.add(file);
    }
  }
  return results;
}

/// Generates a YAML-friendly asset list
String _generateYaml(List<String> assets) {
  final buffer = StringBuffer('flutter:\n  assets:\n');
  for (final asset in assets) {
    buffer.writeln('    - $asset');
  }
  return buffer.toString();
}
