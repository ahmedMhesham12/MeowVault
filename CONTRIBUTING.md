# Contributing

Thanks for helping improve MeowVault.

## Development

```bash
./setup.sh
```

Before opening a pull request, run:

```bash
swift test
swift build -c release --arch x86_64 --arch arm64
```

## Guidelines

- Keep the app native and lightweight.
- Do not commit local clipboard data, keys, build products, or DMGs.
- Keep storage private and local-first.
- Prefer focused changes with tests for core behavior.
