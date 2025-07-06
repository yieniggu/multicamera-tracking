# 📹 Multi-Camera RTSP Viewer (Flutter)

A cross-platform Flutter app to manage and view multiple RTSP camera streams, built with a clean hexagonal architecture and real-time video playback support via VLC.

---

## ✨ Features

- 📱 **Android & iOS support**
- 🔁 **RTSP live streaming** via `flutter_vlc_player`
- 🗃️ **Local storage** using `Hive`
- ➕ Add, edit, delete cameras
- 🖼️ Optional preview thumbnails (manual entry)
- ⚙️ Structured with clean hexagonal layers
- 🧪 Dependency Injection via `get_it`

---

## 📐 Architecture

- `domain/`: Business logic (entities, repositories)
- `data/`: Data layer (Hive models, Firestore soon)
- `presentation/`: UI, widgets, screens
- `config/`: DI, providers, constants

---

## 🛠️ Tech Stack

- Flutter 3.22+
- Hive
- flutter_vlc_player
- get_it for DI
- Upcoming: Firebase Auth & Firestore (Cloud mode)
- Upcoming: Riverpod for reactive state management

---

## 🚀 Getting Started

```bash
git clone https://github.com/your-username/multi-camera-viewer.git
cd multi-camera-viewer
flutter pub get
flutter run
````

### To run on a real Android device:

- Enable Developer Options & USB Debugging
- Connect your device
- Run: ```flutter run```


## 🗓️ Roadmap
### ✅ v0.1.0 – Local MVP

- Add/remove/edit RTSP cameras
- Store camera data in Hive 
- View streams via VLC player
- Dependency injection via get_it

### 🔜 v0.2.0 – Cloud Sync & Auth
- Firebase Auth (email, anonymous)
- Firestore camera/project sync
- User roles and permissions (admin/editor/viewer)
- Project/group/camera organization
- State management with Riverpod

## 💡 Inspiration
Built to power a modular real-time multi-camera tracking system with future CV integration and alerts.

## 👨‍💻 Author
Bastian Simpertigue

Open to collaboration, freelance or full-time backend/flutter roles.