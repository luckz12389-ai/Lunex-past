#!/usr/bin/env bash
set -e

mkdir -p .github/workflows supabase

cat > package.json <<'FILE'
{
  "name": "lunex-paste",
  "version": "1.0.0",
  "private": true,
  "main": "node_modules/expo/AppEntry.js",
  "scripts": {
    "start": "expo start",
    "android": "expo run:android"
  },
  "dependencies": {
    "@supabase/supabase-js": "^2.57.0",
    "expo": "~54.0.0",
    "expo-status-bar": "~3.0.0",
    "react": "19.1.0",
    "react-native": "0.81.4"
  },
  "devDependencies": {
    "@babel/core": "^7.25.2"
  }
}
FILE

cat > app.json <<'FILE'
{
  "expo": {
    "name": "Lunex Paste",
    "slug": "lunex-paste",
    "version": "1.0.0",
    "orientation": "portrait",
    "userInterfaceStyle": "dark",
    "android": {
      "package": "com.lunex.paste",
      "versionCode": 1,
      "permissions": []
    }
  }
}
FILE

cat > babel.config.js <<'FILE'
module.exports = function(api) {
  api.cache(true);
  return { presets: ['babel-preset-expo'] };
};
FILE

cat > App.js <<'FILE'
import React, { useEffect, useState } from 'react';
import {
  SafeAreaView, View, Text, TextInput, TouchableOpacity,
  FlatList, Alert, StyleSheet, ScrollView, Share, ActivityIndicator
} from 'react-native';
import { StatusBar } from 'expo-status-bar';
import { createClient } from '@supabase/supabase-js';

const URL = process.env.EXPO_PUBLIC_SUPABASE_URL || '';
const KEY = process.env.EXPO_PUBLIC_SUPABASE_ANON_KEY || '';
const supabase = URL && KEY ? createClient(URL, KEY) : null;

export default function App() {
  const [session, setSession] = useState(null);
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [title, setTitle] = useState('');
  const [code, setCode] = useState('');
  const [pastes, setPastes] = useState([]);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    if (!supabase) return;
    supabase.auth.getSession().then(({ data }) => setSession(data.session));
    const { data: listener } = supabase.auth.onAuthStateChange((_event, s) => setSession(s));
    return () => listener.subscription.unsubscribe();
  }, []);

  async function auth(mode) {
    if (!supabase) {
      Alert.alert('Configuração necessária', 'Configure os secrets do Supabase no GitHub Actions.');
      return;
    }
    setLoading(true);
    const result = mode === 'signup'
      ? await supabase.auth.signUp({ email: email.trim(), password })
      : await supabase.auth.signInWithPassword({ email: email.trim(), password });
    setLoading(false);
    if (result.error) Alert.alert('Erro', result.error.message);
    else if (mode === 'signup' && !result.data.session)
      Alert.alert('Verifique seu e-mail', 'Confirme seu endereço de e-mail para entrar.');
  }

  async function loadPastes() {
    if (!supabase || !session) return;
    const { data, error } = await supabase.from('pastes')
      .select('*').order('created_at', { ascending: false });
    if (error) Alert.alert('Erro', error.message);
    else setPastes(data || []);
  }

  useEffect(() => { loadPastes(); }, [session]);

  async function createPaste() {
    if (!title.trim() || !code.trim()) {
      Alert.alert('Faltam dados', 'Informe um título e o código.');
      return;
    }
    setLoading(true);
    const { error } = await supabase.from('pastes').insert({
      user_id: session.user.id,
      title: title.trim(),
      content: code
    });
    setLoading(false);
    if (error) Alert.alert('Erro', error.message);
    else {
      setTitle('');
      setCode('');
      loadPastes();
      Alert.alert('Salvo', 'Seu paste foi criado.');
    }
  }

  async function sharePaste(item) {
    const { error } = await supabase.from('pastes')
      .update({ is_public: true }).eq('id', item.id);
    if (error) return Alert.alert('Erro', error.message);
    const base = process.env.EXPO_PUBLIC_PUBLIC_WEB_URL || '';
    const link = base ? `${base}?id=${item.id}` : `ID do paste: ${item.id}`;
    await Share.share({ message: `Meu paste no Lunex Paste: ${link}` });
    loadPastes();
  }

  async function deletePaste(id) {
    const { error } = await supabase.from('pastes').delete().eq('id', id);
    if (error) Alert.alert('Erro', error.message);
    else loadPastes();
  }

  return (
    <SafeAreaView style={s.page}>
      <StatusBar style="light" />
      <ScrollView contentContainerStyle={s.content}>
        <Text style={s.brand}>LUNEX<Text style={s.purple}> PASTE</Text></Text>
        <Text style={s.sub}>SEU CÓDIGO. ORGANIZADO.</Text>

        {!supabase ? (
          <View style={s.card}>
            <Text style={s.heading}>Configuração pendente</Text>
            <Text style={s.muted}>O app foi criado. Configure o projeto Supabase e os secrets do GitHub para habilitar login e armazenamento online.</Text>
          </View>
        ) : !session ? (
          <View style={s.card}>
            <Text style={s.heading}>Acesse sua conta</Text>
            <TextInput style={s.input} placeholder="E-mail" placeholderTextColor="#777" autoCapitalize="none" keyboardType="email-address" value={email} onChangeText={setEmail} />
            <TextInput style={s.input} placeholder="Senha (mínimo 6 caracteres)" placeholderTextColor="#777" secureTextEntry value={password} onChangeText={setPassword} />
            <TouchableOpacity style={s.button} onPress={() => auth('signin')} disabled={loading}>
              <Text style={s.buttonText}>{loading ? 'AGUARDE...' : 'ENTRAR'}</Text>
            </TouchableOpacity>
            <TouchableOpacity style={s.outline} onPress={() => auth('signup')}>
              <Text style={s.outlineText}>CRIAR CONTA</Text>
            </TouchableOpacity>
          </View>
        ) : (
          <>
            <View style={s.card}>
              <Text style={s.heading}>Novo paste</Text>
              <TextInput style={s.input} placeholder="Título do código" placeholderTextColor="#777" value={title} onChangeText={setTitle} />
              <TextInput style={[s.input, s.code]} placeholder="Cole seu código aqui..." placeholderTextColor="#777" value={code} onChangeText={setCode} multiline textAlignVertical="top" />
              <TouchableOpacity style={s.button} onPress={createPaste} disabled={loading}>
                <Text style={s.buttonText}>{loading ? 'SALVANDO...' : 'SALVAR PASTE'}</Text>
              </TouchableOpacity>
            </View>
            <View style={s.row}>
              <Text style={s.heading}>Meus pastes</Text>
              <TouchableOpacity onPress={loadPastes}><Text style={s.purple}>ATUALIZAR</Text></TouchableOpacity>
            </View>
            <FlatList
              data={pastes}
              scrollEnabled={false}
              keyExtractor={item => String(item.id)}
              ListEmptyComponent={<Text style={s.muted}>Nenhum paste ainda.</Text>}
              renderItem={({ item }) => (
                <View style={s.paste}>
                  <Text style={s.pasteTitle}>{item.title}</Text>
                  <Text style={s.muted} numberOfLines={2}>{item.content}</Text>
                  <View style={s.actions}>
                    <TouchableOpacity onPress={() => sharePaste(item)}><Text style={s.purple}>COMPARTILHAR</Text></TouchableOpacity>
                    <TouchableOpacity onPress={() => deletePaste(item.id)}><Text style={s.red}>EXCLUIR</Text></TouchableOpacity>
                  </View>
                </View>
              )}
            />
            <TouchableOpacity style={s.outline} onPress={() => supabase.auth.signOut()}>
              <Text style={s.outlineText}>SAIR DA CONTA</Text>
            </TouchableOpacity>
          </>
        )}
        <Text style={s.footer}>LUNEX PASTE • DESENVOLVIDO PARA CRIADORES</Text>
      </ScrollView>
    </SafeAreaView>
  );
}

const s = StyleSheet.create({
  page: { flex: 1, backgroundColor: '#08080d' },
  content: { padding: 20, paddingTop: 35, paddingBottom: 45 },
  brand: { color: '#fff', fontSize: 32, fontWeight: '900', letterSpacing: 2 },
  purple: { color: '#a855f7', fontWeight: '800' },
  sub: { color: '#777', letterSpacing: 3, fontSize: 10, marginTop: 5, marginBottom: 25 },
  card: { backgroundColor: '#12121c', borderColor: '#292039', borderWidth: 1, borderRadius: 16, padding: 17, marginBottom: 22 },
  heading: { color: '#fff', fontSize: 18, fontWeight: '800', marginBottom: 13 },
  muted: { color: '#999', fontSize: 13, lineHeight: 20, marginBottom: 8 },
  input: { backgroundColor: '#090910', borderColor: '#30263f', borderWidth: 1, borderRadius: 10, color: '#fff', padding: 13, marginBottom: 12 },
  code: { minHeight: 145, fontFamily: 'monospace' },
  button: { backgroundColor: '#9333ea', padding: 15, borderRadius: 10, alignItems: 'center', marginTop: 4 },
  buttonText: { color: '#fff', fontWeight: '900', letterSpacing: 1 },
  outline: { borderColor: '#663399', borderWidth: 1, padding: 13, borderRadius: 10, alignItems: 'center', marginTop: 12 },
  outlineText: { color: '#c084fc', fontWeight: '800' },
  row: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center' },
  paste: { backgroundColor: '#12121c', borderColor: '#292039', borderWidth: 1, borderRadius: 12, padding: 14, marginBottom: 12 },
  pasteTitle: { color: '#fff', fontSize: 16, fontWeight: '800', marginBottom: 8 },
  actions: { flexDirection: 'row', justifyContent: 'space-between', marginTop: 10 },
  red: { color: '#fb7185', fontWeight: '800' },
  footer: { textAlign: 'center', color: '#555', fontSize: 9, letterSpacing: 1, marginTop: 30 }
});
FILE

cat > supabase/schema.sql <<'FILE'
create extension if not exists pgcrypto;

create table if not exists public.pastes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null,
  content text not null,
  is_public boolean not null default false,
  created_at timestamptz not null default now()
);

alter table public.pastes enable row level security;

drop policy if exists "Read own or public pastes" on public.pastes;
create policy "Read own or public pastes" on public.pastes
for select to authenticated
using (auth.uid() = user_id or is_public = true);

drop policy if exists "Create own pastes" on public.pastes;
create policy "Create own pastes" on public.pastes
for insert to authenticated
with check (auth.uid() = user_id);

drop policy if exists "Update own pastes" on public.pastes;
create policy "Update own pastes" on public.pastes
for update to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists "Delete own pastes" on public.pastes;
create policy "Delete own pastes" on public.pastes
for delete to authenticated
using (auth.uid() = user_id);

grant select, insert, update, delete on public.pastes to authenticated;
FILE

cat > index.html <<'FILE'
<!doctype html>
<html lang="pt-BR">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Lunex Paste</title>
<style>
*{box-sizing:border-box}body{margin:0;background:#08080d;color:#eee;font-family:system-ui,sans-serif;padding:24px}
main{max-width:850px;margin:40px auto}.brand{font-size:30px;font-weight:900;letter-spacing:2px}.purple{color:#a855f7}
.card{margin-top:24px;background:#12121c;border:1px solid #30263f;border-radius:16px;padding:20px}
h1{font-size:22px}pre{white-space:pre-wrap;overflow-wrap:anywhere;background:#08080d;padding:18px;border-radius:10px;color:#d8b4fe}
button{background:#9333ea;color:white;border:0;border-radius:8px;padding:12px 16px;font-weight:800}
.muted{color:#999}
</style>
</head>
<body><main>
<div class="brand">LUNEX <span class="purple">PASTE</span></div>
<p class="muted">CÓDIGO COMPARTILHADO</p>
<div class="card" id="result"><h1>Carregando paste...</h1></div>
</main>
<script>
const params = new URLSearchParams(location.search);
const id = params.get('id');
const url = 'REPLACE_SUPABASE_URL';
const key = 'REPLACE_SUPABASE_ANON_KEY';
const out = document.getElementById('result');
async function run(){
 if(!id){out.innerHTML='<h1>Nenhum paste selecionado</h1><p class="muted">Abra um link de compartilhamento válido.</p>';return}
 if(url.startsWith('REPLACE_')||key.startsWith('REPLACE_')){out.innerHTML='<h1>Site ainda não configurado</h1>';return}
 try{
  const r=await fetch(url+'/rest/v1/pastes?id=eq.'+encodeURIComponent(id)+'&is_public=eq.true&select=title,content,created_at',{headers:{apikey:key,Authorization:'Bearer '+key}});
  const data=await r.json();
  if(!r.ok||!data.length){out.innerHTML='<h1>Paste não encontrado</h1>';return}
  const item=data[0];
  const h=document.createElement('h1');h.textContent=item.title;
  const pre=document.createElement('pre');pre.textContent=item.content;
  const b=document.createElement('button');b.textContent='COPIAR CÓDIGO';b.onclick=()=>navigator.clipboard.writeText(item.content).then(()=>b.textContent='COPIADO!');
  out.replaceChildren(h,pre,b);
 }catch(e){out.textContent='Não foi possível carregar este paste.'}
}
run();
</script>
</body>
</html>
FILE

cat > .github/workflows/build-apk.yml <<'FILE'
name: Build Lunex Paste APK
on:
  workflow_dispatch:
  push:
    branches: [main]
permissions:
  contents: read
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4
      - name: Setup Node
        uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: npm
      - name: Setup Java
        uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: '17'
      - name: Install dependencies
        run: npm install
      - name: Generate Android project
        run: npx expo prebuild --platform android --no-install
        env:
          EXPO_PUBLIC_SUPABASE_URL: \${{ secrets.EXPO_PUBLIC_SUPABASE_URL }}
          EXPO_PUBLIC_SUPABASE_ANON_KEY: \${{ secrets.EXPO_PUBLIC_SUPABASE_ANON_KEY }}
          EXPO_PUBLIC_PUBLIC_WEB_URL: \${{ secrets.EXPO_PUBLIC_PUBLIC_WEB_URL }}
      - name: Build APK
        working-directory: android
        run: ./gradlew assembleRelease
      - name: Upload APK
        uses: actions/upload-artifact@v4
        with:
          name: lunex-paste-apk
          path: android/app/build/outputs/apk/release/app-release.apk
          if-no-files-found: error
FILE

cat > .gitignore <<'FILE'
node_modules/
.expo/
android/
ios/
.env
FILE

cat > README.md <<'FILE'
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
FILE

echo "Arquivos do Lunex Paste criados."
