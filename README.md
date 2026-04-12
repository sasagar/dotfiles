# dotfiles

[chezmoi](https://www.chezmoi.io/) と [age](https://github.com/FiloSottile/age) を使って dotfiles と SSH 鍵を管理するリポジトリです。

## 特徴

- **複数PC対応**: `work` / `personal` の2種類のマシンで設定を切り替え
- **age 暗号化**: SSH 秘密鍵や機密設定は age で暗号化して public リポジトリに安全に保存
- **テンプレート化**: メールアドレスやホスト固有の設定は chezmoi データ変数で差し替え
- **自動インストール**: Brewfile と mise 設定に変更があれば `chezmoi apply` 時に自動反映

## 管理対象

### 通常ファイル

| ファイル | 内容 |
|---|---|
| `~/.zshrc`, `~/.zshenv`, `~/.zprofile` | Zsh 設定 |
| `~/.bashrc` | Bash 設定 |
| `~/.vimrc` | Vim 設定 |
| `~/.tmux.conf` | tmux 設定 |
| `~/.fzf.zsh`, `~/.fzf.bash` | fzf 設定 |
| `~/.config/mise/config.toml` | mise のランタイム定義 |
| `~/.ssh/id_ed25519_github.pub` | SSH 公開鍵 |

### テンプレート（`.tmpl`）

| ファイル | テンプレート化の理由 |
|---|---|
| `~/.gitconfig` | `user.email` をデータ変数化、`includeIf` で会社リポジトリ用に上書き |
| `~/.gitconfig-lapras` | 会社リポジトリ用のメールアドレスを分離 |
| `~/.ssh/config` | OrbStack の include 行を work のみに限定 |
| `~/.config/starship.toml` | work / personal で完全に分岐 |

### age 暗号化ファイル

| ファイル | 内容 |
|---|---|
| `~/.ssh/id_ed25519_github` | GitHub 用 SSH 秘密鍵 |
| `~/.zshrc.work` | 会社固有の zsh alias（AWS ECR 設定など） |

## 新しい PC へのセットアップ

### 1. Homebrew と必須ツールのインストール

```bash
# Homebrew を未インストールならまず入れる
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# chezmoi と age を先に入れる
brew install chezmoi age
```

### 2. VaultWarden から age 秘密鍵と chezmoi.toml を取り出す

age 秘密鍵と chezmoi.toml は VaultWarden のセキュアノート
**`dotfiles / chezmoi age key & config`** に添付されている。

#### Web UI で取り出す場合

1. VaultWarden にログイン
2. セキュアノート `dotfiles / chezmoi age key & config` を開く
3. 添付ファイル `key.txt` と `chezmoi.toml` をダウンロード
4. `~/.config/chezmoi/` に配置

#### Bitwarden CLI で取り出す場合

```bash
# 必要なら Bitwarden CLI を先にインストール
brew install bitwarden-cli

# セルフホストの場合はサーバー URL を設定
bw config server https://vw.REDACTED.example.com

# ログインして unlock
bw login                          # 初回のみ
export BW_SESSION=$(bw unlock --raw)

# アイテム ID を検索
ITEM_ID=$(bw list items --search "chezmoi age key" | jq -r '.[0].id')

# 添付ファイルをダウンロード
mkdir -p ~/.config/chezmoi
bw get attachment key.txt \
  --itemid "$ITEM_ID" \
  --output ~/.config/chezmoi/key.txt
bw get attachment chezmoi.toml \
  --itemid "$ITEM_ID" \
  --output ~/.config/chezmoi/chezmoi.toml

chmod 600 ~/.config/chezmoi/key.txt ~/.config/chezmoi/chezmoi.toml
```

### 3. chezmoi.toml の machine 変数を調整する

`~/.config/chezmoi/chezmoi.toml` の `machine` をセットアップする PC に合わせて
`work` / `personal` のいずれかに変更する。

```toml
[data]
  machine = "personal"  # または "work"
```

参考までに chezmoi.toml の構成:

```toml
encryption = "age"

[age]
  identity = "~/.config/chezmoi/key.txt"
  recipient = "<age 公開鍵>"

[data]
  machine = "personal"
  email_personal = "<個人メール>"
  email_work = "<会社メール>"
```

### 4. dotfiles の取得と適用

```bash
chezmoi init --apply sasagar/dotfiles
```

これで以下が一括で実行される:

- リポジトリのクローン
- テンプレート展開
- age 暗号化ファイルの復号
- `run_onchange_*` スクリプトによる Homebrew パッケージと mise ツールのインストール

## 日常の運用

### 管理対象を追加する

```bash
chezmoi add ~/.foo                  # 通常ファイル
chezmoi add --template ~/.foo       # テンプレートとして追加
chezmoi add --encrypt ~/.foo        # age 暗号化して追加
```

### 変更を確認・適用する

```bash
chezmoi diff       # ローカルとソースの差分を確認
chezmoi apply      # ソースの内容をローカルに適用
chezmoi re-add     # ローカルの変更をソースに反映（テンプレート化されていないファイル）
```

### リポジトリを同期する

```bash
chezmoi update     # git pull + apply
chezmoi git push   # ソースリポジトリにプッシュ
```

### 設定を編集する

```bash
chezmoi edit ~/.zshrc    # ソースファイルをエディタで開く
chezmoi cd               # ソースディレクトリに移動
```

## ディレクトリ構成

```
.
├── Brewfile                                      # Homebrew パッケージリスト
├── dot_bashrc                                    # → ~/.bashrc
├── dot_config/
│   ├── mise/config.toml                          # → ~/.config/mise/config.toml
│   └── starship.toml.tmpl                        # → ~/.config/starship.toml (テンプレート)
├── dot_fzf.bash                                  # → ~/.fzf.bash
├── dot_fzf.zsh                                   # → ~/.fzf.zsh
├── dot_gitconfig.tmpl                            # → ~/.gitconfig (テンプレート)
├── dot_gitconfig-lapras.tmpl                     # → ~/.gitconfig-lapras (テンプレート)
├── dot_tmux.conf                                 # → ~/.tmux.conf
├── dot_vimrc                                     # → ~/.vimrc
├── dot_zprofile                                  # → ~/.zprofile
├── dot_zshenv                                    # → ~/.zshenv
├── dot_zshrc                                     # → ~/.zshrc
├── encrypted_private_dot_zshrc.work.age          # → ~/.zshrc.work (暗号化)
├── private_dot_ssh/
│   ├── config.tmpl                               # → ~/.ssh/config (テンプレート)
│   ├── encrypted_private_id_ed25519_github.age   # → ~/.ssh/id_ed25519_github (暗号化)
│   └── id_ed25519_github.pub                     # → ~/.ssh/id_ed25519_github.pub
├── run_onchange_before_install-packages.sh.tmpl  # Brewfile 変更時に brew bundle を実行
└── run_onchange_after_install-mise-tools.sh.tmpl # mise 設定変更時に mise install を実行
```

## ファイル名の命名規則

chezmoi のソースディレクトリでは特別な prefix / suffix でファイルの扱いが決まる:

| prefix / suffix | 意味 |
|---|---|
| `dot_` | 展開時に `.` に変換（例: `dot_zshrc` → `.zshrc`） |
| `private_` | パーミッション 600 に設定 |
| `encrypted_` | age で暗号化されていることを示す |
| `.tmpl` | テンプレートとして処理される |
| `run_once_` | `chezmoi apply` で1回だけ実行 |
| `run_onchange_` | ファイル内容が変わるたびに実行 |

## 関連リンク

- [chezmoi 公式ドキュメント](https://www.chezmoi.io/)
- [age](https://github.com/FiloSottile/age)
