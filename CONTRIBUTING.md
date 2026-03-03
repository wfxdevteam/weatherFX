# Contributing

Thank you for your interest in contributing to this project!

## How to contribute

### 1. Forking the repository

Create the fork

<img width="850" alt="fork" src="https://github.com/user-attachments/assets/68080ba6-bd82-4caf-9680-1f5cadae06e0" />

> [!IMPORTANT]
> Make sure you're selecting your personal account as the owner.

> [!IMPORTANT]
> The "Copy the `master` branch only" option will be enabled by default, it is important you disable it,  
> since we don't usually accept PRs for the master branch! [More info below](#contributing-guidelines)
<img width="550" alt="fork-settings" src="https://github.com/user-attachments/assets/c05df9fe-6465-44fe-bd98-264a768263c2" />

If you see a new repository appear on your personal profile then you did everything correctly, and can move onto the next step.

### 2. Clone it to your local machine

In your new repository, click on the green `Code` button and copy the web URL.

<img width="350" alt="img" src="https://github.com/user-attachments/assets/af3a68d7-bf16-4d1e-9a58-5ece0084551c" />

> [!NOTE]
> If you want to clone the repo directly to your Assetto Corsa root folder, you *can* do that.
> But I would strongly advise against that, as it would pollute your root folder with everything that is in the repo root.
> If you do it though, you can skip the next step.

Then open a terminal in a separate empty folder you want to clone it to and run:

```sh
git clone https://github.com/wfxdevteam/weatherFX.git
```

If you see your folder is now filled with the repository's contents, you did everything correctly and can move onto the next step.

### 3. Symlinking
Symlinking allows you to work directly in your cloned repository without having to manually copy files over every time you make a change.

If you're on Windows, open Command Prompt (cmd) **as administrator** and run:

```cmd
mklink /D "PATH_TO_YOUR_ROOT_FOLDER\assettocorsa\extension\weather\wfx" "PATH_TO_YOUR_CLONE\wfx"
```

If you see a shortcut arrow appear on the `wfx` folder in your `assettocorsa\extension\weather` directory, you did everything correctly.

If you're on Linux/Mac:

```sh
ln -s "PATH_TO_YOUR_CLONE/wfx" "PATH_TO_YOUR_ROOT_FOLDER/assettocorsa/extension/weather/wfx"
```

You can verify the symlink was created correctly by running:
```sh
ls -la "PATH_TO_YOUR_ROOT_FOLDER/assettocorsa/extension/weather/"
```
If you see `wfx -> PATH_TO_YOUR_CLONE/wfx` in the output, you did everything correctly.

### Great! You’re ready to start contributing.
If you need help with a specific part of this guide, feel free to reach us on our [Discord](https://discord.gg/Z82zauQkrd).
Also take a look at the Contributing Guidelines below to see how we handle contributions.

## Contributing guidelines

### General guidelines

- Clearly describe what was changed.
- For major changes, open an issue first to discuss your idea.
- Ensure changes work with the latest CSP version. (Preferably latest preview version)
- Follow the existing structure and naming conventions.
- Do not modify unrelated parts of the project. (README.md, The file you're reading right now, etc.)

### Branching

- Always create pull requests against the `dev` branch.
- Do not push or open PRs directly to `master`.

### Pull Requests

- A pull request should be reviewed by at least one maintainer before merging.
- Keep PRs relatively small and easy to review.
- Write clear and descriptive titles.

### Testing

- Test your changes in-game before submitting.
- Avoid breaking existing behavior.
