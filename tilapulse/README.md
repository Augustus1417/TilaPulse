# tilapulse

## Run On A Physical Android Phone

Start the backend from the repository's `server` directory:

```powershell
python -m uvicorn app.main:app --host 0.0.0.0 --port 8000
```

Keep the phone and computer on the same Wi-Fi network, then run the Flutter app with the computer's LAN address:

```powershell
flutter run -d "SM A556E" --dart-define=API_BASE_URL=http://192.168.18.49:8000
```

Replace the IP address if the computer's Wi-Fi address changes. `10.0.2.2` is for an Android emulator and does not work for a physical phone.

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
