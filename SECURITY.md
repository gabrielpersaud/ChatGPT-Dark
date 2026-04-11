# Security Policy

## Reporting a Vulnerability

If you discover a security issue in this project, please open an issue in this repository:

- https://github.com/gabrielpersaud/ChatGPT-Dark/issues

Please include:

- a short description of the issue
- affected macOS version
- affected ChatGPT app version
- steps to reproduce
- any relevant logs or screenshots

## Scope

This project is a local macOS helper that:

- attaches to the official ChatGPT macOS app at runtime
- overrides appearance-related behavior to force Dark Aqua
- does not persist changes to the ChatGPT app itself

## Project Limits

This project is not intended to:

- collect personal data
- exfiltrate user content
- transmit telemetry or analytics
- modify unrelated applications

## User Review

Because this tool uses runtime instrumentation and requires elevated system trust decisions from the user, you should review the source before running it and only download builds from the official GitHub Releases page for this repository.
