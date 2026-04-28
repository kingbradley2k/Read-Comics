import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Extracts contents from RAR archives using the unrar CLI tool.
/// Works on desktop (Windows/macOS/Linux) where unrar is installed.
/// On mobile, shows a clear error instructing the user to install unrar.
class RarExtractor {
  RarExtractor._();

  static String? _unrarCmd;

  /// Find the unrar executable on the system.
  static Future<String?> _findUnrar() async {
    if (_unrarCmd != null) return _unrarCmd;

    final candidates = Platform.isWindows
        ? ['unrar.exe', 'UnRAR.exe']
        : ['unrar', 'UnRAR'];

    for (final cmd in candidates) {
      try {
        final result = await Process.run(cmd, ['-?'], runInShell: true);
        if (result.exitCode == 0 || result.exitCode == 7) {
          _unrarCmd = cmd;
          return cmd;
        }
      } catch (_) {
        // Command not found, try next
      }
    }

    // Try to find in PATH on Unix systems
    if (!Platform.isWindows) {
      try {
        final result = await Process.run('which', ['unrar'], runInShell: true);
        if (result.exitCode == 0) {
          final path = (result.stdout as String).trim();
          if (path.isNotEmpty) {
            _unrarCmd = path;
            return path;
          }
        }
      } catch (_) {}
    }

    return null;
  }

  /// Returns true if unrar CLI is available.
  static Future<bool> get isAvailable async => await _findUnrar() != null;

  /// List all files in a RAR archive (bare filenames, one per line).
  static Future<List<String>> listFiles(String rarPath) async {
    final unrar = await _findUnrar();
    if (unrar == null) {
      throw RarNotAvailableException(
        'RAR/CBR support requires the "unrar" command-line tool. '
        'Install it and restart the app. '
        '(Windows: https://www.rarlab.com/rar_add.htm)',
      );
    }

    final result = await Process.run(unrar, ['lb', rarPath], runInShell: true);
    if (result.exitCode != 0) {
      throw RarException('Failed to list RAR contents: ${result.stderr}');
    }

    return (result.stdout as String)
        .split('\n')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  /// Extract a specific file to a temp directory and return the file path.
  static Future<String> extractFileToTemp(String rarPath, String entryName) async {
    final unrar = await _findUnrar();
    if (unrar == null) {
      throw RarNotAvailableException('unrar CLI not found.');
    }

    final tempDir = await getTemporaryDirectory();
    final extractDir = Directory(
      p.join(tempDir.path, 'rar_extract_${DateTime.now().millisecondsSinceEpoch}'),
    );
    await extractDir.create(recursive: true);

    final result = await Process.run(
      unrar,
      ['x', '-o+', '-inul', rarPath, entryName, extractDir.path + p.separator],
      runInShell: true,
      workingDirectory: extractDir.path,
    );

    if (result.exitCode != 0) {
      throw RarException(
        'Failed to extract "$entryName" from RAR: ${result.stderr}',
      );
    }

    // Find the extracted file
    final expectedPath = p.join(extractDir.path, entryName);
    if (await File(expectedPath).exists()) return expectedPath;

    // Fallback: search recursively for the filename
    final files = await extractDir.list(recursive: true).toList();
    for (final entity in files) {
      if (entity is File && p.basename(entity.path) == p.basename(entryName)) {
        return entity.path;
      }
    }

    throw RarException('Extracted file not found: $entryName');
  }

  /// Extract a specific file and return its bytes. Cleans up temp file after.
  static Future<Uint8List> extractFileBytes(String rarPath, String entryName) async {
    final path = await extractFileToTemp(rarPath, entryName);
    try {
      return await File(path).readAsBytes();
    } finally {
      // Best-effort cleanup
      try {
        await File(path).delete();
        await Directory(p.dirname(path)).delete(recursive: true);
      } catch (_) {}
    }
  }
}

class RarException implements Exception {
  final String message;
  RarException(this.message);
  @override
  String toString() => message;
}

class RarNotAvailableException extends RarException {
  RarNotAvailableException(super.message);
}

