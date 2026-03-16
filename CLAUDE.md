# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

TurfGo is a Flutter application targeting iOS, Android, web, macOS, Linux, and Windows. It uses Dart SDK ^3.8.1 and is currently at version 1.0.0+1.

## Common Commands

- **Run the app:** `flutter run`
- **Run tests:** `flutter test`
- **Run a single test file:** `flutter test test/widget_test.dart`
- **Analyze code:** `flutter analyze`
- **Get dependencies:** `flutter pub get`
- **Format code:** `dart format .`
- **Build:** `flutter build <platform>` (e.g., `apk`, `ios`, `web`, `macos`)

## Architecture

The project is currently the default Flutter counter app scaffold. All application code lives in `lib/main.dart` with a single widget test in `test/widget_test.dart`.

## Linting

Uses `package:flutter_lints/flutter.yaml` as the base lint ruleset, configured in `analysis_options.yaml`.
