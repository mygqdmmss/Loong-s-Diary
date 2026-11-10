param(
    [Parameter(Mandatory = $true)]
    [string]$FlutterSdk
)

$ErrorActionPreference = 'Stop'
$taskRepo = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$taskSdk = (Resolve-Path -LiteralPath $FlutterSdk).Path
$taskDart = Join-Path $taskSdk 'bin/cache/dart-sdk/bin/dart.exe'
$taskPackages = Join-Path $taskSdk 'packages/flutter_tools/.dart_tool/package_config.json'
if (!(Test-Path -LiteralPath (Join-Path $taskRepo '.dart_tool/package_config.json'))) {
    throw 'Resolve the cached app dependencies with flutter pub get --offline first.'
}
if (!(Test-Path -LiteralPath $taskDart) -or !(Test-Path -LiteralPath $taskPackages)) {
    throw 'The specified Flutter SDK must have its Dart runtime and flutter_tools dependencies cached.'
}

# Use the installed Flutter SDK's own Android generator. This avoids unrelated
# desktop symlink setup and does not change global Flutter or Windows settings.
$taskScratch = Join-Path $taskRepo 'build/android-plugin-tool'
New-Item -ItemType Directory -Path $taskScratch -Force | Out-Null
$taskGenerator = Join-Path $taskScratch 'generate.dart'
@'
import 'dart:io';
import 'package:flutter_tools/src/cache.dart';
import 'package:flutter_tools/src/base/template.dart';
import 'package:flutter_tools/src/context_runner.dart';
import 'package:flutter_tools/src/flutter_plugins.dart';
import 'package:flutter_tools/src/isolated/mustache_template.dart';
import 'package:flutter_tools/src/project.dart';

Future<void> main(List<String> args) async {
  Cache.flutterRoot = args[0];
  Directory.current = args[1];
  await runInContext(() async {
    await injectPlugins(
      FlutterProject.current(),
      releaseMode: true,
      androidPlatform: true,
    );
  }, overrides: {TemplateRenderer: () => const MustacheTemplateRenderer()});
}
'@ | Set-Content -LiteralPath $taskGenerator -Encoding UTF8

& $taskDart "--packages=$taskPackages" $taskGenerator $taskSdk $taskRepo
if ($LASTEXITCODE -ne 0) { throw 'Flutter Android plugin generation failed.' }
$taskRegistrant = Join-Path $taskRepo 'android/app/src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java'
if (!(Test-Path -LiteralPath $taskRegistrant)) { throw 'Flutter did not generate the Android registrant.' }
$taskSource = Get-Content -LiteralPath $taskRegistrant -Raw
foreach ($taskPlugin in @('SharedPreferencesPlugin', 'PathProviderPlugin', 'PackageInfoPlugin')) {
    if (!$taskSource.Contains($taskPlugin)) { throw "Missing startup plugin: $taskPlugin" }
}
Write-Output "Android plugin registration generated: $taskRegistrant"
