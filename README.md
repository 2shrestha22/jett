# Jett

A minimal, fast file transfer app inspired by [LocalSend](https://github.com/localsend/localsend).

<img src="jett.png" alt="Jett Logo" width="100"/>

[<img src="https://img.shields.io/badge/Google_Play-414141?style=for-the-badge&logo=google-play&logoColor=white" alt="Get it on Google Play Store">](https://play.google.com/store/apps/details?id=com.sangamshrestha.jett)
[<img src="https://img.shields.io/badge/App_Store-0D96F6?style=for-the-badge&logo=app-store&logoColor=white" alt="Get it on AppStore">](https://apps.apple.com/us/app/jett-file-transfer/id6753203602)

<img width="2234" height="1172" alt="image" src="https://github.com/user-attachments/assets/db30dc77-dec9-4a2b-9908-fa97bdd05e97" />

## Code generation

Generated files are committed, so regenerating is part of a change rather than
a build step — commit the output alongside the source.

| after changing | run |
|---|---|
| `rust/src/api/**` | `flutter_rust_bridge_codegen generate` |
| `pigeons/input.dart` | `./pigeon.sh` |
| a `@MappableClass` | `dart run build_runner build --delete-conflicting-outputs` |

Rust changes **outside `rust/src/api/`** need nothing: that directory is the
whole FFI surface. Not sure? Run the generator and check `git status` — clean
means you were already in sync.
