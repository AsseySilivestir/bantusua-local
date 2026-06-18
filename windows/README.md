# ChatBantu for Windows

> **Spring Initializer-style:** download, unzip, run. No installs, no internet, no WSL, no Docker.

## What's in this zip

```
chatbantu-windows-x64/
├── bantu.exe              ← the Bantu interpreter (native Windows binary)
├── server.b               ← the entire ChatBantu backend (one file)
├── public/                ← frontend (HTML/CSS/JS, no build step)
│
├── start.bat              ← double-click to launch + open browser
├── stop.bat               ← kill the server
├── reset-db.bat           ← wipe chatbantu.db and reseed
├── README.md              ← this file
│
└── (runtime DLLs)
    ├── sqlite3.dll        ← SQLite runtime
    ├── libcurl-x64.dll    ← libcurl runtime (+ its bundled TLS deps)
    ├── libc++.dll         ← C++ standard library (llvm-mingw)
    ├── libunwind.dll      ← stack unwinding (libc++ dep)
    └── libwinpthread-1.dll← pthreads emulation
```

Nothing else is needed. The DLLs cover every external dependency; Windows itself supplies KERNEL32, WS2_32, and the Universal CRT (`api-ms-win-crt-*`), all of which ship with Windows 10 and later.

## How to run

1. **Unzip** the download anywhere — `C:\chatbantu`, your Desktop, a USB stick, doesn't matter.
2. **Double-click `start.bat`.**
3. A console window opens, the server boots, and your default browser opens to `http://localhost:8080`.

That's it. No PowerShell, no `npm install`, no `pip`, no `apt-get`. If you want to run it from PowerShell or CMD instead, just `cd` into the folder and run:

```powershell
.\start.bat
```

## Login

The first run creates `chatbantu.db` with a demo user:

- **username:** `silivestir`
- **password:** `bantu123`

## Stopping

- Close the **"ChatBantu Server"** console window, **or**
- Run `stop.bat`.

## Wiping the database

Run `reset-db.bat`. The next `start.bat` will recreate `chatbantu.db` from scratch with the demo user.

## Changing the port

From PowerShell:

```powershell
$env:PORT=9000
.\start.bat
```

From CMD:

```cmd
set PORT=9000
start.bat
```

## Troubleshooting

**"Windows protected your PC" / SmartScreen warning**

The .exe is unsigned, so Windows shows a blue SmartScreen prompt. Click **"More info" → "Run anyway"**. To avoid this permanently, sign the .exe with a code-signing certificate (not bundled here).

**`start.bat` flashes and disappears**

Run it from an existing PowerShell / CMD window so the error stays visible:

```powershell
cd C:\chatbantu
.\start.bat
```

Then check `server.log` — that's where the Bantu interpreter's stderr goes.

**Port 8080 is already in use**

Set `PORT` to something else (see "Changing the port" above).

**Antivirus quarantines `bantu.exe`**

Some AV products are suspicious of unsigned executables that listen on a port. Add the folder to your AV exclusions, or build `bantu.exe` yourself from source on your own machine (see the `bantusua-local` repo's `bantu-src/compiler/build-win.sh`).

**`bantu.exe` won't start and there's no error in server.log**

Open `cmd.exe`, `cd` to the folder, and run `bantu.exe --version` directly. If Windows complains about missing DLLs, restore the DLLs from the zip — they're all required.

## System requirements

- Windows 10 (1809+) or Windows 11, 64-bit
- ~50 MB free disk space
- A browser (any modern one — Edge, Chrome, Firefox)
- No admin rights needed

## What this is

ChatBantu is a real-world social network (posts, likes, comments, follow, real-time chat, presence, notifications, WebRTC video calls) built entirely with the **Bantu** programming language and its **Sua** web framework — no Node.js, no Python, no other runtime. The backend is a single `server.b` file interpreted by `bantu.exe`.

Source code: https://github.com/AsseySilivestir/bantusua-local
