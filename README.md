[README_登入修正.md](https://github.com/user-attachments/files/29655323/README_.md)
# RealEstateAI V7 GitHub Pages / Supabase 登入修正版

## 這版修正什麼

你原本卡住的錯誤：

```text
Unexpected token '<', '<html> <he'... is not valid JSON
```

原因是 Supabase 設定填錯：

- `SUPABASE_URL` 被填成 GitHub Pages 網址：`https://mike888-ui.github.io/Pages`
- `SUPABASE_ANON_KEY` 被填成 GitHub Commit 的 GPG Key：`B5690...`

這兩個都不是 Supabase 的 API 設定，所以登入時系統去 GitHub Pages 抓資料，拿到的是 HTML，不是 JSON，就會報錯。

## 正確填法

### SUPABASE_URL

到 Supabase 專案後台找 Project URL，格式應該像：

```text
https://xxxx.supabase.co
```

不可填：

```text
https://mike888-ui.github.io/Pages
```

### SUPABASE_ANON_KEY

到 Supabase：

```text
Project Settings → API → Project API keys → anon public
```

複製 `anon public key`，通常會以 `eyJ` 開頭，而且很長。

不可填 GitHub 顯示的 GPG Key。

## GitHub Pages 覆蓋方式

1. 把本資料夾的 `index.html` 上傳覆蓋 GitHub repo 裡的 `index.html`
2. 等 GitHub Pages 重新部署
3. 打開：

```text
https://mike888-ui.github.io/Pages
```

4. 進入「Supabase 設定」
5. 先按「清除設定」
6. 貼上正確 Supabase Project URL 與 anon public key
7. 儲存設定
8. 回到「登入 / 申請帳號」

## 已加入的防呆

- 如果 URL 不是 `*.supabase.co`，會直接阻擋
- 如果 anon key 不是 JWT 格式，會直接阻擋
- 不會再跳出不清楚的 JSON 錯誤
- 會顯示「目前 Supabase 設定錯誤」與修正說明
