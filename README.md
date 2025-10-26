# 🧠 TCRDD — Test, Commit, Revert Driven Development

**TCRDD** is a Bash tool that extends Git with a new command: `git-bet`.  
It automates the *Test → Commit → Revert* workflow, helping you code with higher discipline and safety.

---

## 🚀 Features

### 🎯 Core commands

| Command | Description |
|----------|-------------|
| `git-bet pass <command>` | Run tests — if they pass, automatically commit changes. If they fail, revert code. |
| `git-bet fail <command>` | Expect failure — if tests unexpectedly pass, revert code. Otherwise, do nothing. |
| `git-bet timer <minutes> <command>` | Run `git-bet pass` every _N_ minutes automatically in the background. |
| `git-bet timer 0` | Stop the background timer and log tail. |
| `git-bet collapse` | Interactively squash a chosen number of recent commits into one. |

---

## 💡 Aliases

| Alias | Expands to | Description |
|--------|-------------|-------------|
| `gbp` | `git-bet pass` | Bet that tests will pass |
| `gbf` | `git-bet fail` | Bet that tests will fail |
| `gbt` | `git-bet timer` | Start or stop the timed auto-run |
| `gbc` | `git-bet collapse` | Collapse last commits interactively |

---

## ⚙️ Installation

1. Clone this repository:

   ```bash
   git clone https://github.com/yourname/tcrdd.git
   ```

2. Copy the content of tcrdd.sh into your ~/.zshrc or ~/.bash_profile or ~/.bashrc 
    
3. Reload your shell :

    ```bash
        source ~/.bash_profile
    ```
    or
    ```bash
        source ~/.zshrc
    ```
    or
    ```bash
        source ~/.bashrc
    ```

4. Check
    ```bash
        type git-bet
        type gbp
        type gbf
        type gbc
        type gbt
    ```

### Platform compatibility

`TCRDD` uses standard Bash and Git commands, so it should run on any system with:
- Bash ≥ 4.0
- Git installed

It has been tested successfully on:

- **macOS (default zsh with Bash compatibility)**
- **Debian Bullseye Slim (via Node 20 Docker image)**

These environments cover most Linux and Unix-like systems.  
Other distros (Ubuntu, Fedora, Arch, etc.) are expected to behave identically.

Here is the test procedure if needed.

- Debian Bullseye slim
    ```bash
        docker run -it --rm \
        -v "$PWD/tcrdd.sh":/home/tcrdd/tcrdd.sh \
        -v "$PWD/test-platforms":/home/tcrdd/test-platforms \
         -w /home/tcrdd \
        node:20-bullseye-slim \
        bash -c "apt-get update && apt-get install -y git && bash -l"
        
        source tcrdd.sh
        git config --global user.email "you@example.com"
        git config --global user.name "Your Name"
        cd test-platforms
        git init        
        npm i
        gbp npm test
    ```

- Alpine BusyBox
    ```bash
        docker run -it --rm \
        -v "$PWD/tcrdd.sh":/home/tcrdd/tcrdd.sh \
        -v "$PWD/test-platforms":/home/tcrdd/test-platforms \
        -w /home/tcrdd \
        alpine \
        sh -c "apk add --no-cache bash git nodejs npm && exec bash"

        source tcrdd.sh
        git config --global user.email "you@example.com"
        git config --global user.name "Your Name"
        cd test-platforms
        git init
        npm i
        gbp npm test
    ```
