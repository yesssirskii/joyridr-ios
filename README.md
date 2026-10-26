# JOYRIDR iOS

SwiftUI app for JOYRIDR (iOS 27, Xcode 27). The backend lives in [`joyridr`](https://github.com/yesssirskii/joyridr).

## Run it

1. Start the backend (`dotnet run --project joyridr` in the backend repo). It listens on `http://localhost:5105`.
2. Open `joyridr-ios.xcodeproj` and run on an iPhone Simulator.
3. In the Simulator, set a location near the demo cars: **Features › Location › Custom Location…** `45.8131, 15.9775` (Zagreb).
   Without location permission the app falls back to Zagreb anyway.
4. Log in with a demo account (password `Password123!`): `rider@joyridr.dev` or `driver@joyridr.dev`, or sign up.

## Run it on your iPhone

The app works straight from the home screen and talks to the backend on your Mac over Wi-Fi.

1. Start the backend as usual. In Development it listens on your whole network (port 5105), not just on the Mac.
2. Make sure the iPhone and the Mac are on the **same Wi-Fi**.
3. In Xcode pick your iPhone as the run destination and press Run (once is enough; after that you can open it from the home screen).
4. On first launch, tap **Allow** for Local Network access (and Location).

Phone builds use the `JOYRIDR_API_URL` build setting (target › Build Settings › User-Defined), currently
`http://M2-MacBook-Air.local:5105`. The `.local` name keeps working when your Mac's IP address changes.
On a different Mac, change it to that Mac's name (System Settings › General › Sharing › Local hostname).

The Simulator always uses `http://localhost:5105`. To override either one temporarily, set a
`JOYRIDR_API_URL` environment variable in the scheme (Product › Scheme › Edit Scheme › Run › Arguments).

If the app says it can't reach the server, the message shows the address it tried.

## Project layout

```
Info.plist          Only holds JoyridrAPIURL; everything else is generated from build settings
joyridr-ios/
├── App/            Entry point and RootView (login vs rider app vs driver app)
├── Core/
│   ├── Networking/ APIClient (requests, JSON, errors, automatic token refresh)
│   ├── Auth/       TokenStore (Keychain) and SessionStore (who's logged in)
│   └── Location/   One-shot location for the nearby search
├── Models/         Codable structs that mirror the backend's JSON
├── DesignSystem/   Theme (colours, fonts), racing stripes, buttons, fields, shared components
└── Features/
    ├── Auth/       Login, choose role, sign up
    ├── Rider/      Explore (nearby cars)
    ├── Driver/     Ride requests (confirm/decline) and upcoming rides
    └── Profile/    Profile sheet with log out
```

How data flows: a screen owns an `@Observable` model (e.g. `ExploreModel`), the model calls `APIClient`, and the view re-renders when the model's properties change. `SessionStore` is shared through `.environment(...)`.

## Not built yet

My rides, car detail + booking, chat, the driver's My cars and Schedule tabs (they show "coming soon" screens), Google/Apple sign-in, password reset, and the custom display font (`Theme.display` uses SF Pro Expanded as a stand-in).
