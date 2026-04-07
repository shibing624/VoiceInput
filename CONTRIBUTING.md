# Contributing to VoiceInput

Thanks for your interest in contributing! Here's how you can help.

## Getting Started

1. Fork the repository
2. Clone your fork: `git clone https://github.com/<you>/voice-input.git`
3. Make sure you have **Xcode Command Line Tools**: `xcode-select --install`
4. Build: `make build`
5. Run: `make run`

## Development Workflow

```bash
make build      # compile + assemble VoiceInput.app
make run        # build + launch
make clean      # remove build artifacts
```

Icon generation requires Python 3 + Pillow:

```bash
pip install Pillow
make icon
```

## Submitting Changes

1. Create a feature branch: `git checkout -b feature/my-change`
2. Make your changes
3. Test locally with `make run`
4. Commit with a clear message
5. Push and open a Pull Request

## Guidelines

- Keep PRs focused — one feature or fix per PR
- Follow the existing code style (Swift 5.9, macOS 14+ APIs)
- Update README if adding user-facing features
- Test on macOS 14+ before submitting

## Reporting Bugs

Open an issue with:

- macOS version
- Steps to reproduce
- Expected vs. actual behavior
- Console logs if applicable (`Console.app` → filter by "VoiceInput")

## License

By contributing, you agree that your contributions will be licensed under the [Apache License 2.0](LICENSE).
