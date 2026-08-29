# Yellow_SNSeducation

黄色チームのリポジトリです

## 開発環境構築(Flutter)

### 前提条件

- Git
- Flutter SDK(このプロジェクトは 3.29.0 で作成しています)

### 1. Flutter SDKのインストール

公式サイトの手順に従ってインストールしてください。
[Install Flutter](https://docs.flutter.dev/get-started/install)

インストール後、`flutter` コマンドにPATHを通してください。

### 2. リポジトリのクローン

```sh
git clone <このリポジトリのURL>
cd Yellow_SNSeducation
```

### 3. 依存パッケージの取得

```sh
flutter pub get
```

### 4. 環境の確認

以下のコマンドで、開発に必要なツールが揃っているか確認できます。

```sh
flutter doctor
```

`[!]` や `[X]` が表示された項目は、指示に従って解消してください。特に以下は開発対象に応じて必要です。

- **Android開発**: Android Studio + Android SDK
- **Web開発**: Chromeなどのブラウザ
- **Windowsデスクトップ開発**: Visual Studio(「Desktop development with C++」ワークロードが必要)

### 5. アプリの起動

接続可能なデバイス・エミュレータの一覧を確認:

```sh
flutter devices
```

任意のデバイスで起動(例: Chrome):

```sh
flutter run -d chrome
```

Windowsデスクトップアプリとして起動する場合:

```sh
flutter run -d windows
```

### 推奨エディタ

- VS Code(Flutter拡張機能を導入)
- Android Studio(Flutter/Dartプラグインを導入)
