# Lunex Paste

Aplicativo Android de pastes com login, armazenamento no Supabase e compartilhamento por link.

## Configuração do Supabase
1. Crie um projeto em https://supabase.com/
2. Abra SQL Editor e execute todo o conteúdo de `supabase/schema.sql`.
3. Em Project Settings / API, copie a Project URL e a chave publicável/anon. Nunca use a chave `service_role`.

## Secrets do GitHub
Em Settings > Secrets and variables > Actions, crie:
- `EXPO_PUBLIC_SUPABASE_URL`
- `EXPO_PUBLIC_SUPABASE_ANON_KEY`
- `EXPO_PUBLIC_PUBLIC_WEB_URL` (URL pública do site terminando com `/`)

## Site público
Configure GitHub Pages para publicar a branch `main`, pasta `/ (root)`. Depois edite `index.html` e substitua `REPLACE_SUPABASE_URL` e `REPLACE_SUPABASE_ANON_KEY` pelos valores públicos do Supabase.

## APK
Abra Actions, selecione Build Lunex Paste APK e clique Run workflow. O APK ficará nos artifacts da execução.
