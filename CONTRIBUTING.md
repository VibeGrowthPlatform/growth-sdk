# Contributing

Thanks for contributing to the Vibe Growth SDKs.

## Development

Run the full validation suite before opening a pull request:

```bash
bash scripts/validate-sdks.sh
```

This runs builds, unit tests, Flutter analysis, and a vendored-source sync
check that ensures the Flutter and Unity packages stay byte-identical to the
native Android and iOS sources.

### Updating SDK behavior

The iOS (`ios/`) and Android (`android/`) packages are the source of truth.
When you change native behavior, update the vendored copies under
`flutter/ios/Classes/`, `flutter/android/src/main/kotlin/`,
`unity/Plugins/iOS/Sources/`, and `unity/Plugins/Android/src/main/kotlin/` so
that `validate-sdks.sh` still passes.

### Real-backend validation

With a Vibe Growth backend running locally on `http://localhost:8000`:

```bash
bash scripts/validate-sdks.sh --e2e
bash scripts/validate-android-example-e2e.sh
```

## Pull requests

- Keep changes scoped to one SDK per PR when possible.
- Include unit tests for behavior changes.
- Update per-SDK READMEs when public API changes.
- Match the existing code style in each package.

## Reporting bugs

Please open a GitHub issue with the SDK name, version, platform/OS, and a
minimal reproduction.

## License

By contributing you agree that your contributions will be licensed under the
repository's [MIT License](LICENSE).
