# Kamaae — Claude Instructions

## Before committing any code

Always run both of these and fix all issues before committing:

```bash
flutter analyze
flutter test
```

### Important: CI uses Flutter 3.47.2 (stable)

Local Flutter may be an older version that silently ignores lint issues CI will catch.
`flutter analyze` must exit with code 0 (zero issues) — not just zero errors in source
files. Check `git status` after any automated fixes to confirm changes were actually
staged before committing.
