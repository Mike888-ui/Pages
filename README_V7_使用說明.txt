RealEstateAI V7｜黑科技賣屋雲端系統

本版已依需求修正：
1. 完整黑科技風格網頁格式
2. Supabase 權限登入
3. 買方可申請帳號密碼，登入後才能瀏覽賣屋資訊
4. 新增買方詢問問題，AI BOT 自動產生回覆並儲存紀錄
5. 主權限人 Admin 可新增賣屋資料與更新賣屋資訊
6. 主權限人可加入照片、刪除照片、修改相關資訊
7. 物件狀態新增「已售出」
8. 表格、照片、文字框支援上下左右捲動與 resize，不會被框架限制
9. 主頁面已加入黑科技賣屋背景與深色科技 UI

使用步驟：
1. 到 Supabase 建立新 Project。
2. 開啟 SQL Editor，貼上 supabase_schema.sql 全部內容並 Run。
3. 開啟 Authentication → Providers，確認 Email 登入已啟用。
4. 打開 index.html。
5. 到「Supabase 設定」貼上 Project URL 與 anon public key。
6. 第一個申請帳號會自動成為主權限人 Admin。
7. 主權限人登入後，可新增物件、改已售出、加入或刪除照片。
8. 買方申請帳號登入後，可瀏覽物件並使用 AI BOT 詢問。

主權限人手動設定：
如果第一個帳號不是你，請到 Supabase SQL Editor 執行：
update public.profiles set role='admin' where email='你的信箱@example.com';

照片功能說明：
- Starter 版支援「照片網址」與「本機上傳轉 data URL」。
- 若正式大量上線，建議後續改成 Supabase Storage 圖片桶，效能會更好。

部署方式：
可直接放到 Netlify、Cloudflare Pages、GitHub Pages，或任何靜態網站空間。
