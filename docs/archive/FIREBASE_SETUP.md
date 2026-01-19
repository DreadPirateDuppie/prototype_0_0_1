# Firebase Setup Instructions

## 1. Login to Firebase
I've installed the Firebase CLI for you. Now you need to authenticate.
Run this command in your terminal:
```bash
firebase login
```
Follow the instructions in your browser to log in.

## 2. Configure FlutterFire
Once logged in, run the configuration command using the full path (since it's not in your PATH):

```bash
~/.pub-cache/bin/flutterfire configure --project=pushinn-10e98
```

## 3. Add to PATH (Optional)
To fix the "command not found" error permanently, add this to your shell config (`~/.zshrc`):
```bash
export PATH="$PATH":"$HOME/.pub-cache/bin"
```
Then run `source ~/.zshrc`.
