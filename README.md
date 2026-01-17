# 📔 デジタル交換日記(API)

デジタル交換日記のAPIの実装です。

## ⚡ 起動方法

1. `mix setup` (初回起動時のみ)

1. `just run`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

Ready to run in production? Please [check our deployment guides](https://hexdocs.pm/phoenix/deployment.html).

## 📦 仕様

詳しい仕様は[`openapi.yaml`](./openapi.yaml)を参照してください。

| **パス**          | **メソッド** | **概要**                     |
| :---------------- | :----------: | :--------------------------- |
| `/api/diary`      |    `POST`    | 新規日記の作成               |
| `/api/diary/{id}` |    `GET`     | 指定した日記の全ページを取得 |
| `/api/diary/{id}` |    `PUT`     | 指定した日記を更新           |

## 🚩 TODO

- [ ] 日記

  - [x] 作成

  - [ ] 閲覧

  - [ ] エクスポート

- [ ] ページ

  - [ ] 追加

- [ ] 認証
