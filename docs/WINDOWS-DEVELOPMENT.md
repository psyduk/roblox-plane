# Windows development

Install Git for Windows, Python 3.13, VS Code, and Roblox Studio. Reopen your terminal after installation so it sees the updated PATH. This repository uses a Python packager; Rojo is not required.

## Build and test locally

Open the repository folder in VS Code, then use its PowerShell terminal:

```powershell
py -3.13 scripts/build.py --output build/Sky-Battle-Playtest.rbxlx
py -3.13 scripts/validate_package.py --place build/Sky-Battle-Playtest.rbxlx
```

If the build command fails, fix that error before validating or opening the output. The explicit output keeps the tracked `Skybound.rbxlx` unchanged while you experiment. Both commands use only Python's standard library.

In Roblox Studio, sign in with your own account and open `build/Sky-Battle-Playtest.rbxlx` from this checkout. Press Studio Play, then the hangar PLAY button. Expect rival search, card selection, and a first-to-two plane battle. Stop Play before editing.

Edit game code in `src/` and tests in `tests/`. After every build, close and reopen the generated place in Studio; it does not automatically reload the disk file. Manual script edits inside the generated Studio place are not copied back to source. Building and local testing do not publish the game.

## Share changes through GitHub

Your brother must invite your GitHub account as a repository collaborator, and you must accept. GitHub authentication and Git commit identity are separate: setting a commit email does not sign you in.

Configure your preferred commit name and email locally with `git config user.name "Your Name"` and `git config user.email "your-email"` before committing. A GitHub private noreply email also works.

Start future work from an up-to-date main branch when your working tree is clean:

```powershell
git switch main
git pull --ff-only origin main
git switch -c codex/describe-your-change
```

After editing, building, and testing, inspect and commit only your intended files:

```powershell
git status
git diff
git add path/to/changed-file
git commit -m "Describe the change"
git push -u origin HEAD
```

Replace the example file path and branch name with your actual change. Complete GitHub's browser sign-in if prompted. Open a pull request on GitHub for your brother to review and merge. Do not commit generated files under `build/`.

Roblox access is separate from GitHub: your brother grants your Roblox account Edit permission if you need to edit the shared experience. Coordinate publishing with him; local build verification is not a live multiplayer or phone test.
